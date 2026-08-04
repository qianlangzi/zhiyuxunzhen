import 'package:flutter/material.dart';

import '../config/api_config.dart';

/// 应用全局常量
class AppConstants {
  AppConstants._();

  /// 应用名称
  static const String appName = '智愈寻真';

  /// 应用版本
  static const String appVersion = '2.1.0';

  /// 医学免责声明
  static const String medicalDisclaimer =
      '系统提供内容仅供医学思维训练，不具备真实临床诊疗效力。';

  /// API 基础地址（来自 ApiConfig，可通过 `--dart-define=API_BASE_URL=...` 注入）
  static const String apiBaseUrl = ApiConfig.apiBaseUrl;

  /// AI 中台地址（来自 ApiConfig，可通过 `--dart-define=AI_BASE_URL=...` 注入）
  static const String aiBaseUrl = ApiConfig.aiBaseUrl;

  /// 角色
  static const int roleStudent = 0;
  static const int roleTeacher = 1;
  static const int roleSecretary = 2;
  static const int roleDirector = 3;
  static const int roleAdmin = 4;
  static const int roleOps = 5;

  /// 图片上传限制
  static const int maxImageSizeMB = 5;
  static const int maxImagesPerSession = 5;

  /// 思维树节点上限
  static const int maxTreeNodes = 50;

  /// 检查费用阈值
  static const double defaultCostThreshold = 1000.0;

  /// 知识点标签上限
  static const int maxKnowledgeTags = 8;

  /// 每日一例编号
  static const int dailyCaseNumber = 213;

  /// 热力图天数
  static const int heatmapDays = 365;
}

/// 圆角半径
class AppRadius {
  AppRadius._();

  static const double xs = 2.0;
  static const double sm = 6.0;
  static const double md = 10.0;
  static const double lg = 14.0;
  static const double xl = 20.0;
}

/// 间距
class AppSpacing {
  AppSpacing._();

  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double xxxl = 32.0;
}

/// 页面内边距
class AppPadding {
  AppPadding._();

  static const EdgeInsets pageHorizontal = EdgeInsets.symmetric(horizontal: 20);
  static const EdgeInsets page = EdgeInsets.symmetric(horizontal: 20, vertical: 16);
  static const EdgeInsets pageBottom = EdgeInsets.only(left: 20, right: 20, bottom: 100);
}

/// 安全存储 Key（flutter_secure_storage）
///
/// 用于存放「生物识别可登录角色」，退出登录时清除。
class SecureKeys {
  SecureKeys._();

  /// 生物识别可登录角色标记：'student' | 'teacher'
  static const String biometricRole = 'biometric_login_role';
}
