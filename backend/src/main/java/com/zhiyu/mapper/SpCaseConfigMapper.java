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
     * 随机抽取今日「每日一例」候选病例（发布时间/审核通过/含标准诊断）。
     *
     * 采用「最久未推荐优先」轮转：从未上过每日一例的病例优先（随机关联打平），
     * 已用病例则按最近一次排期时间升序、最久远的优先，从而实现复用时避免短期重复。
     * 因此病例库不会因全部排过一次而耗尽，每日一例可持续生成。
     *
     * @return 命中的病例，库中无可发布病例时返回 null
     */
    @Select("""
            SELECT c.* FROM sp_case_config c
            WHERE c.status = 1 AND c.admin_audit_status = 2 AND c.is_deleted = 0
              AND c.reference_answer IS NOT NULL AND c.reference_answer <> ''
            ORDER BY (
                SELECT COALESCE(MAX(d.publish_date), '1970-01-01')
                FROM daily_case_schedule d WHERE d.case_id = c.id
            ) ASC, RAND()
            LIMIT 1
            """)
    SpCaseConfig selectRandomDailyCase();

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
