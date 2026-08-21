import 'package:flutter/material.dart';

import '../config/api_config.dart';
import '../theme/app_colors.dart';

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

/// 圆角半径（圆润化体系）
///
/// 借鉴 Apple / Material 3「更大圆角＝更灵动」的设计语言，
/// 在保留东方纸墨美学的前提下整体上调，营造柔和、亲和、有温度的质感。
class AppRadius {
  AppRadius._();

  /// 极小圆角：进度条、细标签等（纯线元素）
  static const double xs = 6.0;

  /// 小圆角：按钮、输入框、图标底、标签
  static const double sm = 12.0;

  /// 中圆角：卡片、分区容器（默认）
  static const double md = 18.0;

  /// 大圆角：Bento 大卡、浮层
  static const double lg = 24.0;

  /// 特大圆角
  static const double xl = 30.0;

  /// 全圆（胶囊/圆形）
  static const double full = 999.0;
}

/// 阴影层级（柔和·低透明·多方向，仿 iOS 材质层叠）
///
/// 用「极淡阴影 + 少量扩散」替代生硬边框，让卡片有悬浮的立体层次，
/// 同时保持宣纸米白的通透感。所有阴影颜色需配合当前主题亮暗自适应。
class AppShadow {
  AppShadow._();

  /// 卡片默认投影（很淡，几乎不可见的悬浮感）
  static List<BoxShadow> card(BuildContext ctx) => [
        BoxShadow(
          color: Color.lerp(Colors.transparent, AppColors.moss, 0.06)!,
          offset: const Offset(0, 5),
          blurRadius: 16,
          spreadRadius: 0,
        ),
        BoxShadow(
          color: Color.lerp(Colors.transparent, AppColors.moss, 0.03)!,
          offset: const Offset(0, 1),
          blurRadius: 3,
          spreadRadius: 0,
        ),
      ];

  /// 部件浮起投影（按钮、底部导航浮层）
  static List<BoxShadow> lifted(BuildContext ctx) => [
        BoxShadow(
          color: Color.lerp(Colors.transparent, AppColors.moss, 0.12)!,
          offset: const Offset(0, 8),
          blurRadius: 24,
          spreadRadius: 0,
        ),
        BoxShadow(
          color: Color.lerp(Colors.transparent, AppColors.moss, 0.05)!,
          offset: const Offset(0, 2),
          blurRadius: 6,
          spreadRadius: 0,
        ),
      ];
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
/// 用于存放「生物识别可登录角色」与 JWT 凭证，退出登录时清除。
class SecureKeys {
  SecureKeys._();

  /// 生物识别可登录角色标记：'student' | 'teacher'
  static const String biometricRole = 'biometric_login_role';

  /// access token（JWT），请求头 Authorization: Bearer xxx
  static const String accessToken = 'auth_access_token';

  /// refresh token，用于 access token 过期后换取新 token
  static const String refreshToken = 'auth_refresh_token';
}
