package com.zhiyu.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.zhiyu.entity.Drug;
import org.apache.ibatis.annotations.Mapper;

/** 药品库 Mapper（PRD 训练中心 · 药房，只读为主） */
@Mapper
public interface DrugMapper extends BaseMapper<Drug> {
}
