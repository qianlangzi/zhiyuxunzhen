package com.zhiyu.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.zhiyu.common.constant.ResultCode;
import com.zhiyu.common.context.UserContext;
import com.zhiyu.common.exception.BizException;
import com.zhiyu.common.result.PageResult;
import com.zhiyu.entity.Textbook;
import com.zhiyu.mapper.TextbookMapper;
import com.zhiyu.service.TextbookService;
import com.zhiyu.service.PdfCoverService;
import com.zhiyu.service.dto.TextbookCreateDTO;
import com.zhiyu.vo.TextbookVO;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.util.StringUtils;

import java.util.Collections;
import java.util.List;
import java.util.Objects;
import java.util.stream.Collectors;

/**
 * 教材中心服务实现
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class TextbookServiceImpl implements TextbookService {

    /** 科室元数据进程内缓存 TTL：教材中心每次进入都会拉一次科室列表，缓存避免重复查库 */
    private static final long META_CACHE_TTL_MS = 5 * 60 * 1000L;
    private static volatile List<String> departmentsCache;
    private static volatile long departmentsCacheAt;

    private final TextbookMapper textbookMapper;
    private final ObjectMapper objectMapper;
    private final PdfCoverService pdfCoverService;

    @Override
    public PageResult<TextbookVO> page(Integer pageNum, Integer pageSize, String department, String keyword) {
        Page<Textbook> page = new Page<>(pageNum, pageSize);
        LambdaQueryWrapper<Textbook> wrapper = new LambdaQueryWrapper<Textbook>()
                .eq(Textbook::getStatus, 1)
                .eq(StringUtils.hasText(department), Textbook::getDepartment, department)
                .and(StringUtils.hasText(keyword), w -> w
                        .like(Textbook::getTitle, keyword)
                        .or().like(Textbook::getAuthor, keyword)
                        .or().like(Textbook::getKnowledgeTags, keyword))
                .orderByDesc(Textbook::getCreatedAt);
        textbookMapper.selectPage(page, wrapper);

        List<TextbookVO> list = page.getRecords().stream()
                .map(this::toVO)
                .collect(Collectors.toList());
        return PageResult.of(page, list);
    }

    @Override
    public TextbookVO detail(Long id) {
        Textbook tb = textbookMapper.selectById(id);
        if (tb == null || tb.getStatus() == 0) {
            throw new BizException(ResultCode.NOT_FOUND, "教材不存在或已下架");
        }
        return toVO(tb);
    }

    @Override
    public Long create(TextbookCreateDTO dto) {
        Long teacherId = UserContext.requireUserId();
        Textbook tb = new Textbook();
        tb.setCreatorId(teacherId);
        tb.setTitle(dto.getTitle());
        tb.setEdition(dto.getEdition());
        tb.setDepartment(dto.getDepartment());
        tb.setAuthor(dto.getAuthor());
        tb.setPublisher(dto.getPublisher());
        tb.setFileUrl(dto.getFileUrl());
        // 兜底：教师端未传封面且电子书为 PDF 时，自动渲染首页作为封面（失败不影响创建）
        String coverUrl = dto.getCoverUrl();
        if (!StringUtils.hasText(coverUrl) && StringUtils.hasText(dto.getFileUrl())) {
            coverUrl = pdfCoverService.generateCoverForUrl(dto.getFileUrl()).orElse(null);
        }
        tb.setCoverUrl(coverUrl);
        tb.setDescription(dto.getDescription());
        tb.setKnowledgeTags(dto.getKnowledgeTags() == null ? null
                : toJson(dto.getKnowledgeTags()));
        tb.setChapterCount(dto.getChapterCount() == null ? 0 : dto.getChapterCount());
        tb.setPageCount(dto.getPageCount() == null ? 0 : dto.getPageCount());
        tb.setStatus(1);
        textbookMapper.insert(tb);
        evictDepartmentsCache();
        if (tb.getTextbookNo() == null || tb.getTextbookNo().isBlank()) {
            tb.setTextbookNo(String.format("JC%06d", tb.getId()));
            textbookMapper.updateById(tb);
        }
        log.info("教师{}上传教材: {}", teacherId, tb.getId());
        return tb.getId();
    }

    @Override
    public PageResult<TextbookVO> myList(Integer pageNum, Integer pageSize) {
        Long teacherId = UserContext.requireUserId();
        Page<Textbook> page = new Page<>(pageNum, pageSize);
        textbookMapper.selectPage(page, new LambdaQueryWrapper<Textbook>()
                .eq(Textbook::getCreatorId, teacherId)
                .orderByDesc(Textbook::getCreatedAt));
        List<TextbookVO> list = page.getRecords().stream()
                .map(this::toVO)
                .collect(Collectors.toList());
        return PageResult.of(page, list);
    }

    @Override
    public void delete(Long id) {
        Long teacherId = UserContext.requireUserId();
        Textbook tb = textbookMapper.selectById(id);
        if (tb == null) {
            throw new BizException(ResultCode.NOT_FOUND, "教材不存在");
        }
        if (!Objects.equals(tb.getCreatorId(), teacherId)) {
            throw new BizException(ResultCode.FORBIDDEN);
        }
        tb.setStatus(0);
        textbookMapper.updateById(tb);
        evictDepartmentsCache();
    }

    @Override
    public List<String> departments() {
        List<String> cached = departmentsCache;
        if (cached != null && System.currentTimeMillis() - departmentsCacheAt < META_CACHE_TTL_MS) {
            return cached;
        }
        List<String> list = textbookMapper.selectList(
                        new LambdaQueryWrapper<Textbook>()
                                .eq(Textbook::getStatus, 1)
                                .isNotNull(Textbook::getDepartment)
                                .groupBy(Textbook::getDepartment)
                                .select(Textbook::getDepartment))
                .stream()
                .map(Textbook::getDepartment)
                .filter(StringUtils::hasText)
                .collect(Collectors.toList());
        departmentsCache = list;
        departmentsCacheAt = System.currentTimeMillis();
        return list;
    }

    /** 上架/下架教材后调用（新教材可能带来新科室，下架可能删掉唯一科室） */
    private static void evictDepartmentsCache() {
        departmentsCache = null;
        departmentsCacheAt = 0L;
    }

    private TextbookVO toVO(Textbook tb) {
        return toVO(tb, null);
    }

    /**
     * @param mineOverride 非空时直接采用；为空时按当前登录用户是否为创建者推断
     */
    private TextbookVO toVO(Textbook tb, Boolean mineOverride) {
        Boolean mine = mineOverride;
        if (mine == null) {
            try {
                Long uid = UserContext.requireUserId();
                mine = uid != null && Objects.equals(tb.getCreatorId(), uid);
            } catch (Exception e) { // noqa - 未登录等场景降级为不标注
                mine = Boolean.FALSE;
            }
        }
        return TextbookVO.builder()
                .id(tb.getId())
                .textbookNo(tb.getTextbookNo())
                .title(tb.getTitle())
                .edition(tb.getEdition())
                .department(tb.getDepartment())
                .author(tb.getAuthor())
                .publisher(tb.getPublisher())
                .coverUrl(tb.getCoverUrl())
                .fileUrl(tb.getFileUrl())
                .description(tb.getDescription())
                .knowledgeTags(parseTags(tb.getKnowledgeTags()))
                .chapterCount(tb.getChapterCount())
                .pageCount(tb.getPageCount())
                .ingestStatus(tb.getIngestStatus())
                .mine(mine)
                .build();
    }

    private String toJson(Object obj) {
        try {
            return objectMapper.writeValueAsString(obj);
        } catch (Exception e) {
            log.warn("序列化教材知识点失败: {}", e.getMessage());
            return null;
        }
    }

    private List<String> parseTags(String json) {
        if (!StringUtils.hasText(json)) {
            return Collections.emptyList();
        }
        try {
            return objectMapper.readValue(json, new TypeReference<List<String>>() {
            });
        } catch (Exception e) {
            log.warn("解析教材知识点失败: {}", json, e);
            return Collections.emptyList();
        }
    }
}