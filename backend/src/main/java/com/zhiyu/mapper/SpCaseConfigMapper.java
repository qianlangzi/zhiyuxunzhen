package com.zhiyu.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.zhiyu.entity.SpCaseConfig;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Update;

@Mapper
public interface SpCaseConfigMapper extends BaseMapper<SpCaseConfig> {

    /**
     * 原子自增引用计数，避免 read-then-write 并发竞态
     *
     * @param id 病例ID
     * @return 受影响行数
     */
    @Update("UPDATE sp_case_config SET reference_count = reference_count + 1 WHERE id = #{id}")
    int incrementReferenceCount(@Param("id") Long id);
}
