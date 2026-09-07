import 'dart:convert';

/// 患者画像解析工具
///
/// 病例库 `sp_case_config.patient_profile` 存的是 JSON 结构（与旧版每日一例
/// 问诊入口同源）：name/age/gender/occupation/allergy/complaint/presentIllness/
/// pastHistory/personality 等。直接展示原文会把 JSON 甩在学生脸上，
/// 本工具把它解析为「患者信息 chips + 主诉 + 病史摘要」；解析失败回退原文。
class PatientProfile {
  /// 患者信息 chips：(label, value)，仅保留非空且非"不详/无"的字段
  final List<(String, String)> chips;

  /// 主诉（可能为空）
  final String complaint;

  /// 病史摘要文本（优先现病史 → 主诉 → 既往史 → 原文兜底）
  final String summary;

  const PatientProfile({
    required this.chips,
    required this.complaint,
    required this.summary,
  });

  /// 是否为空画像
  bool get isEmpty => chips.isEmpty && summary.isEmpty;
}

PatientProfile parsePatientProfile(String? raw) {
  if (raw == null || raw.trim().isEmpty) {
    return const PatientProfile(chips: [], complaint: '', summary: '');
  }
  final text = raw.trim();
  if (!text.startsWith('{')) {
    return PatientProfile(chips: [], complaint: '', summary: text);
  }
  try {
    final decoded = jsonDecode(text);
    if (decoded is! Map<String, dynamic>) {
      return PatientProfile(chips: [], complaint: '', summary: text);
    }
    String pick(String key) {
      final v = decoded[key];
      if (v == null) return '';
      final s = v.toString().trim();
      return s == 'null' ? '' : s;
    }

    bool meaningful(String v) =>
        v.isNotEmpty && v != '不详' && v != '无' && v != '-' && v != '无特殊';

    final chips = <(String, String)>[];
    void add(String label, String value) {
      if (meaningful(value)) chips.add((label, value));
    }

    add('性别', pick('gender'));
    add('年龄', pick('age'));
    add('职业', pick('occupation'));
    add('过敏史', pick('allergy'));

    final complaint = pick('complaint');
    String summary = pick('presentIllness');
    if (summary.isEmpty) summary = complaint;
    if (summary.isEmpty) summary = pick('pastHistory');
    if (summary.isEmpty) summary = text;
    return PatientProfile(chips: chips, complaint: complaint, summary: summary);
  } catch (_) {
    return PatientProfile(chips: [], complaint: '', summary: text);
  }
}
