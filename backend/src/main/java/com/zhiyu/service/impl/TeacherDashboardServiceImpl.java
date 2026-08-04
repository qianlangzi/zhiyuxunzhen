package com.zhiyu.service.impl;

import com.zhiyu.service.TeacherDashboardService;
import com.zhiyu.vo.TeacherDashboardVO;
import org.springframework.stereotype.Service;

import java.util.Arrays;
import java.util.HashMap;
import java.util.Map;

/**
 * 教师学情看板服务实现（模拟数据）
 */
@Service
public class TeacherDashboardServiceImpl implements TeacherDashboardService {

    @Override
    public TeacherDashboardVO getOverview(Long teacherId) {
        // TODO: 从多个表中聚合真实统计数据
        Map<String, Integer> dimensionScores = new HashMap<>();
        dimensionScores.put("病史采集", 85);
        dimensionScores.put("体格检查", 78);
        dimensionScores.put("诊断分析", 82);
        dimensionScores.put("治疗方案", 75);
        dimensionScores.put("沟通能力", 80);

        return TeacherDashboardVO.builder()
                .completionRate(0.76)
                .avgOsceScore(80.5)
                .reviewEfficiency(0.92)
                .overExamRate(0.12)
                .osceDimensionScores(dimensionScores)
                .commonMistakes(Arrays.asList(
                        TeacherDashboardVO.CommonMistake.builder()
                                .type("诊断")
                                .description("鉴别诊断考虑不全面")
                                .count(45)
                                .build(),
                        TeacherDashboardVO.CommonMistake.builder()
                                .type("体格检查")
                                .description("神经系统检查遗漏")
                                .count(38)
                                .build(),
                        TeacherDashboardVO.CommonMistake.builder()
                                .type("病史采集")
                                .description("既往史询问不完整")
                                .count(32)
                                .build()
                ))
                .build();
    }
}