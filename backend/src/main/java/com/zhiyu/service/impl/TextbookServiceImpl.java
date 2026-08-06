package com.zhiyu.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.zhiyu.common.constant.ResultCode;
import com.zhiyu.common.exception.BizException;
import com.zhiyu.common.result.PageResult;
import com.zhiyu.entity.Textbook;
import com.zhiyu.mapper.TextbookMapper;
import com.zhiyu.service.TextbookService;
import com.zhiyu.vo.TextbookVO;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.util.StringUtils;

import java.util.Collections;
import java.util.List;
import java.util.stream.Collectors;

/**
 * 教材中心服务实现
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class TextbookServiceImpl implements TextbookService {

    private final TextbookMapper textbookMapper;
    private final ObjectMapper objectMapper;

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

    private TextbookVO toVO(Textbook tb) {
        return TextbookVO.builder()
                .id(tb.getId())
                .title(tb.getTitle())
                .edition(tb.getEdition())
                .department(tb.getDepartment())
                .author(tb.getAuthor())
                .publisher(tb.getPublisher())
                .coverUrl(tb.getCoverUrl())
                .description(tb.getDescription())
                .knowledgeTags(parseTags(tb.getKnowledgeTags()))
                .chapterCount(tb.getChapterCount())
                .build();
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