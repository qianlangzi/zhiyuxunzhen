package com.zhiyu.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.zhiyu.common.constant.ResultCode;
import com.zhiyu.common.exception.BizException;
import com.zhiyu.common.result.PageResult;
import com.zhiyu.entity.Drug;
import com.zhiyu.mapper.DrugMapper;
import com.zhiyu.service.DrugService;
import com.zhiyu.vo.DrugDetailVO;
import com.zhiyu.vo.DrugFilterVO;
import com.zhiyu.vo.DrugListVO;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.util.StringUtils;

import java.util.Arrays;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;

/** 药品库服务实现（对照 CaseMarketServiceImpl 样板） */
@Slf4j
@Service
@RequiredArgsConstructor
public class DrugServiceImpl implements DrugService {

    private final DrugMapper drugMapper;

    /**
     * LIKE 转义声明：配合 escapeLike 使用，防止用户输入 % / _ 被当成通配符。
     * 必须写成 SQL 文本中的双反斜杠：Java "\\\\" -> SQL "ESCAPE '\\'" -> MySQL 解析为单反斜杠转义符。
     * 若只写 "\\"，MySQL 收到 ESCAPE '\' 会把单引号吃掉，直接 1064 语法错误（对照 CaseMarketServiceImpl 踩坑记录）。
     */
    private static final String ESCAPE_CLAUSE = " ESCAPE '\\\\'";

    private static String escapeLike(String raw) {
        return raw.replace("\\", "\\\\")
                .replace("%", "\\%")
                .replace("_", "\\_");
    }

    @Override
    public PageResult<DrugListVO> list(Integer pageNum, Integer pageSize, List<String> category,
                                       List<String> department, String keyword) {
        Page<Drug> page = new Page<>(pageNum, pageSize);
        LambdaQueryWrapper<Drug> wrapper = new LambdaQueryWrapper<Drug>()
                .eq(Drug::getStatus, 1);

        // 药理分类：多选 IN 等值（去空格去重）
        if (category != null) {
            List<String> cats = category.stream()
                    .map(String::trim)
                    .filter(StringUtils::hasText)
                    .distinct()
                    .toList();
            if (!cats.isEmpty()) {
                wrapper.in(Drug::getCategory, cats);
            }
        }

        // 科室：多条件 OR LIKE（存的是逗号分隔多值，「心血管」可命中「心血管内科」）；
        // 同维度多选 = OR，与药理分类维度之间 = AND
        if (department != null) {
            List<String> deps = department.stream()
                    .map(String::trim)
                    .filter(StringUtils::hasText)
                    .distinct()
                    .toList();
            if (!deps.isEmpty()) {
                wrapper.and(w -> {
                    for (int i = 0; i < deps.size(); i++) {
                        if (i > 0) {
                            w.or();
                        }
                        w.apply("department LIKE CONCAT('%', {0}, '%')" + ESCAPE_CLAUSE,
                                escapeLike(deps.get(i)));
                    }
                });
            }
        }

        // 关键字：通用名 / 商品名 / 适应症 三字段 OR 模糊
        if (StringUtils.hasText(keyword)) {
            final String kw = escapeLike(keyword.trim());
            wrapper.and(w -> w
                    .apply("generic_name LIKE CONCAT('%', {0}, '%')" + ESCAPE_CLAUSE, kw)
                    .or().apply("trade_name LIKE CONCAT('%', {0}, '%')" + ESCAPE_CLAUSE, kw)
                    .or().apply("indications LIKE CONCAT('%', {0}, '%')" + ESCAPE_CLAUSE, kw));
        }

        // 排序：sort 权重降序 → id 降序（新药在前）
        wrapper.orderByDesc(Drug::getSort).orderByDesc(Drug::getId);
        drugMapper.selectPage(page, wrapper);

        List<DrugListVO> list = page.getRecords().stream().map(d -> DrugListVO.builder()
                .id(d.getId())
                .genericName(d.getGenericName())
                .tradeName(d.getTradeName())
                .englishName(d.getEnglishName())
                .category(d.getCategory())
                .department(d.getDepartment())
                .dosageForm(d.getDosageForm())
                .isOtc(d.getIsOtc())
                .build()).collect(Collectors.toList());
        return PageResult.of(page, list);
    }

    @Override
    public DrugFilterVO filters() {
        // 只取分类 / 科室列，避免把 indications 等大文本拉进内存
        List<Drug> rows = drugMapper.selectList(
                new LambdaQueryWrapper<Drug>()
                        .select(Drug::getCategory, Drug::getDepartment)
                        .eq(Drug::getStatus, 1));

        Set<String> categories = new LinkedHashSet<>();
        Set<String> departments = new LinkedHashSet<>();
        for (Drug d : rows) {
            if (StringUtils.hasText(d.getCategory())) {
                categories.add(d.getCategory().trim());
            }
            if (StringUtils.hasText(d.getDepartment())) {
                // department 逗号分隔多值，拆分去重
                Arrays.stream(d.getDepartment().split(","))
                        .map(String::trim)
                        .filter(StringUtils::hasText)
                        .forEach(departments::add);
            }
        }
        List<String> catList = categories.stream().sorted().collect(Collectors.toList());
        List<String> deptList = departments.stream().sorted().collect(Collectors.toList());
        return DrugFilterVO.builder().categories(catList).departments(deptList).build();
    }

    @Override
    public DrugDetailVO detail(Long drugId) {
        Drug d = drugMapper.selectById(drugId);
        if (d == null || d.getStatus() == null || d.getStatus() != 1) {
            throw new BizException(ResultCode.DRUG_NOT_FOUND);
        }
        return DrugDetailVO.builder()
                .id(d.getId())
                .genericName(d.getGenericName())
                .tradeName(d.getTradeName())
                .englishName(d.getEnglishName())
                .category(d.getCategory())
                .department(d.getDepartment())
                .dosageForm(d.getDosageForm())
                .isOtc(d.getIsOtc())
                .indications(d.getIndications())
                .usageDosage(d.getUsageDosage())
                .adverseReactions(d.getAdverseReactions())
                .contraindications(d.getContraindications())
                .precautions(d.getPrecautions())
                .build();
    }
}
