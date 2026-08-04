package com.zhiyu.service.impl;

import com.zhiyu.service.StudentEvaluationService;
import com.zhiyu.vo.SessionEvaluationVO;
import com.zhiyu.vo.ThinkingTreeVO;
import org.springframework.stereotype.Service;

import java.util.Arrays;
import java.util.HashMap;
import java.util.Map;

/**
 * 学生会话评估服务实现（模拟数据）
 */
@Service
public class StudentEvaluationServiceImpl implements StudentEvaluationService {

    @Override
    public SessionEvaluationVO getEvaluation(Long sessionId) {
        // TODO: 从评估表中查询真实数据
        Map<String, Integer> osceScores = new HashMap<>();
        osceScores.put("病史采集", 22);
        osceScores.put("体格检查", 18);
        osceScores.put("诊断分析", 20);
        osceScores.put("治疗方案", 17);
        osceScores.put("沟通能力", 21);

        return SessionEvaluationVO.builder()
                .sessionId(sessionId)
                .caseId(1001L)
                .osceScores(osceScores)
                .strengths(Arrays.asList(
                        "病史采集全面，覆盖主要症状",
                        "与患者沟通态度良好",
                        "诊断思路清晰"
                ))
                .improvements(Arrays.asList(
                        "鉴别诊断需要进一步扩展",
                        "体格检查手法有待规范",
                        "治疗方案需考虑更多个体化因素"
                ))
                .totalScore(98)
                .build();
    }

    @Override
    public ThinkingTreeVO getThinkingTree(Long sessionId) {
        // TODO: 从思维树表中查询真实数据
        return ThinkingTreeVO.builder()
                .sessionId(sessionId)
                .totalExamCost(85.5)
                .symptoms(Arrays.asList(
                        ThinkingTreeVO.SymptomItem.builder()
                                .name("头痛")
                                .description("持续性头痛，伴有恶心")
                                .evidence("患者主诉头痛3天，NRS评分6分")
                                .build(),
                        ThinkingTreeVO.SymptomItem.builder()
                                .name("发热")
                                .description("体温38.5℃，午后明显")
                                .evidence("体温测量38.5℃")
                                .build()
                ))
                .reasoning(Arrays.asList(
                        ThinkingTreeVO.ReasoningItem.builder()
                                .step("初步诊断")
                                .content("考虑上呼吸道感染可能性大")
                                .correct(true)
                                .build(),
                        ThinkingTreeVO.ReasoningItem.builder()
                                .step("鉴别诊断")
                                .content("需要排除脑膜炎")
                                .correct(true)
                                .build(),
                        ThinkingTreeVO.ReasoningItem.builder()
                                .step("辅助检查")
                                .content("建议血常规、CRP检查")
                                .correct(true)
                                .build()
                ))
                .socraticPrompt("请思考：患者头痛伴发热，还有哪些需要警惕的疾病？")
                .build();
    }
}