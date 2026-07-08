package com.zhiyu.service;

import com.zhiyu.vo.FormatCheckResultVO;

/**
 * 大病历格式盾牌校验服务（PRD 5.3）
 * <p>
 * 校验规则：
 * <ul>
 *   <li>必填段落：主诉、现病史、既往史、过敏史、体格检查、辅助检查、初步诊断</li>
 *   <li>主诉字数 ≤ 20</li>
 *   <li>过敏史不允许空白</li>
 * </ul>
 */
public interface FormatCheckService {

    /**
     * 校验大病历正文格式
     *
     * @param medicalRecordText 大病历正文
     * @param formatRuleJson    作业自定义格式规则 JSON（可选，暂以默认规则为准）
     * @return 校验结果
     */
    FormatCheckResultVO check(String medicalRecordText, String formatRuleJson);
}
