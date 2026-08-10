import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// 复盘报告 PDF 生成器（真实数据驱动）
///
/// 数据来源：POST /api/v1/student/review-report/export 返回的 R.data
/// 结构见 ReviewReportVO / ReportSessionVO（osceScoreJson 为 JSON 字符串）。
/// 使用 printing.layoutPdf 提供系统打印/分享/保存能力。
class ReviewReportPdf {
  ReviewReportPdf._();

  static pw.Font? _font;

  /// 加载打包的中文字体（Noto Sans SC）。失败时抛出，由调用方提示。
  static Future<pw.Font> _loadFont() async {
    if (_font != null) return _font!;
    final ByteData data =
        await rootBundle.load('assets/fonts/NotoSansSC.ttf');
    _font = pw.Font.ttf(data);
    return _font!;
  }

  /// 解析四维评分 JSON 字符串为键值列表
  static List<(String, num)> _parseScores(String? osceJson) {
    if (osceJson == null || osceJson.isEmpty) return const [];
    try {
      final decoded = jsonDecode(osceJson) as Map<String, dynamic>;
      final list = decoded.entries
          .map((e) => (e.key, (e.value is num) ? e.value as num : 0))
          .toList();
      list.sort((a, b) => a.$2.compareTo(b.$2));
      return list;
    } catch (_) {
      return const [];
    }
  }

  static String _statusText(int? status) {
    return switch (status) {
      1 => '已完成',
      2 => '异常中断',
      _ => '进行中',
    };
  }

  static String _fmtMoney(num? v) {
    final d = v ?? 0;
    return '¥ ${d.toStringAsFixed(2)}';
  }

  static String _fmtTime(String? iso) {
    if (iso == null || iso.isEmpty) return '--';
    return iso.replaceFirst('T', ' ').substring(0, 16);
  }

  /// 生成报告 PDF 字节
  static Future<Uint8List> build(Map<String, dynamic> data) async {
    final font = await _loadFont();
    final base = pw.ThemeData.withFont(base: font, bold: font);
    final sessions = (data['sessions'] as List?) ?? const [];

    final doc = pw.Document();

    // 封面/概览
    doc.addPage(pw.Page(
      theme: base,
      pageFormat: PdfPageFormat.a4,
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('智愈寻真 · AI 复盘报告',
              style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text('REVIEW REPORT',
              style: pw.TextStyle(fontSize: 11, color: PdfColors.grey600)),
          pw.SizedBox(height: 16),
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _stat('训练次数', '${data['sessionCount'] ?? 0}'),
                _stat('检查总费用', _fmtMoney((data['totalExamCostSum'] as num?)?.toDouble())),
                _stat('生成时间', _fmtTime(data['generatedAt'] as String?)),
              ],
            ),
          ),
          pw.SizedBox(height: 16),
          pw.Text('会话明细',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    ));

    // 会话明细页
    sessions.asMap().forEach((idx, raw) {
      final s = Map<String, dynamic>.from(raw as Map);
      final scores = _parseScores(s['osceScoreJson'] as String?);
      doc.addPage(pw.Page(
        theme: base,
        pageFormat: PdfPageFormat.a4,
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('会话 #${idx + 1}',
                style: pw.TextStyle(fontSize: 11, color: PdfColors.grey600)),
            pw.SizedBox(height: 4),
            pw.Text('${s['caseTitle'] ?? '病例'}',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.Row(children: [
              _chip('状态：${_statusText((s['status'] as num?)?.toInt())}'),
              pw.SizedBox(width: 8),
              _chip('费用：${_fmtMoney((s['totalExamCost'] as num?)?.toDouble())}'),
            ]),
            pw.SizedBox(height: 8),
            pw.Text('结束时间：${_fmtTime(s['endedAt'] as String?)}',
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
            pw.SizedBox(height: 16),
            if (scores.isEmpty)
              pw.Text('暂无四维评分数据（AI 降级模式）',
                  style: const pw.TextStyle(color: PdfColors.grey600))
            else
              pw.TableHelper.fromTextArray(
                headers: ['评分维度', '得分'],
                data: scores.map((e) => [e.$1, '${e.$2}']).toList(),
                border: pw.TableBorder.all(color: PdfColors.grey300),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                cellStyle: const pw.TextStyle(fontSize: 12),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.grey100,
                ),
              ),
          ],
        ),
      ));
    });

    // 免责声明页
    doc.addPage(pw.Page(
      theme: base,
      pageFormat: PdfPageFormat.a4,
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('声明',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Text(
            '本报告由 AI 辅助生成，仅供医学教学训练使用，不具备临床诊疗效力。'
            '评分结果依据问诊会话与预设标准路径计算，如有疑问请咨询带教老师。',
            style: const pw.TextStyle(fontSize: 12, height: 1.6),
          ),
        ],
      ),
    ));

    return doc.save();
  }

  static pw.Widget _stat(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label,
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
        pw.SizedBox(height: 2),
        pw.Text(value,
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
      ],
    );
  }

  static pw.Widget _chip(String text) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(20),
      ),
      child: pw.Text(text, style: const pw.TextStyle(fontSize: 10)),
    );
  }

  /// 导出（系统打印/分享/保存）
  static Future<void> export(Map<String, dynamic> data) async {
    final bytes = await build(data);
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }
}