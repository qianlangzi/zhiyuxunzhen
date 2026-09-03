package com.zhiyu.service.dto;

import lombok.Data;

import java.util.List;

/**
 * 班级排序入参：classIds 按期望的展示顺序排列。
 */
@Data
public class ClassSortDTO {
    private List<Long> classIds;
}