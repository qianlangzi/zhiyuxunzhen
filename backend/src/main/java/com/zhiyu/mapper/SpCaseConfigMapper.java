package com.zhiyu.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.zhiyu.entity.SpCaseConfig;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;
import org.apache.ibatis.annotations.Update;

import java.time.LocalDate;

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

    /**
     * 随机抽取一个"未使用"的每日一例病例：已发布(status=1)+已通过审核(admin_audit_status=2)+
     * 未被标记(is_daily=0)+未删除，且从未进入排期表(daily_case_schedule)。
     *
     * @return 命中的病例，无可用病例返回 null
     */
    @Select("""
            SELECT * FROM sp_case_config
            WHERE is_daily = 0 AND status = 1 AND admin_audit_status = 2 AND is_deleted = 0
              AND NOT EXISTS (SELECT 1 FROM daily_case_schedule d WHERE d.case_id = sp_case_config.id)
            ORDER BY RAND() LIMIT 1
            """)
    SpCaseConfig selectRandomUnusedCase();

    /**
     * 将病例标记为"已被每日一例使用"
     *
     * @param id   病例ID
     * @param date 被选中的日期
     * @return 受影响行数
     */
    @Update("UPDATE sp_case_config SET is_daily = 1, daily_date = #{date} WHERE id = #{id}")
    int markAsDaily(@Param("id") Long id, @Param("date") LocalDate date);
}
