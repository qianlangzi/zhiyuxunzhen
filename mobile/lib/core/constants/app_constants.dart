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

/// 圆角半径（胶囊圆润体系）
///
/// 对齐当前大厂移动端设计语言（iOS / 主流国民 App）：
/// 以「胶囊 + 大圆角」为主旋律，容器尽量圆润、减少方正感。
/// 按钮 / 输入框 / 搜索框 / 标签 / 进度条一律全圆胶囊，
/// 卡片与分区容器使用 20~28 的大圆角，仅极细线元素保留小圆角。
class AppRadius {
  AppRadius._();

  /// 极小圆角：进度条轨道、细分割线等（纯线元素）
  static const double xs = 8.0;

  /// 小圆角：图标底、小标签、内嵌小块
  static const double sm = 14.0;

  /// 中圆角：小卡片、分区容器（默认）
  static const double md = 20.0;

  /// 大圆角：标准卡片、输入框、按钮
  static const double lg = 24.0;

  /// 特大圆角：Hero 大卡、底部弹层、底部悬浮容器
  static const double xl = 28.0;

  /// 全圆（胶囊/圆形）：按钮、输入框、chips、徽章、头像、进度条
  static const double full = 999.0;
}

/// 阴影层级（克制·单层·量化分级）
///
/// v2：去掉"双层阴影叠加"，改为单层、更规范的水平量级，避免"Ai 味"的阴影堆砌。
/// 阴影与渐变不同时叠加在同一元素上。默认 level-1，浮起组件 level-2。
class AppShadow {
  AppShadow._();

  /// 单层投影：`level` 越大越强越柔和（2=卡片淡影，8=浮起组件）
  static List<BoxShadow> leveled({required double level}) {
    final level02 = level.clamp(0.0, 32.0);
    return [
      BoxShadow(
        color: AppColors.ink.withValues(alpha: 0.025 + 0.006 * level02),
        offset: Offset(0, (level02 * 0.5).clamp(1.0, 12.0)),
        blurRadius: (level02 * 0.75).clamp(2.0, 24.0),
        spreadRadius: 0,
      ),
    ];
  }

  /// 卡片默认投影（level 2，很淡的悬浮感）—— 保留同名 API 以兼容旧调用
  static List<BoxShadow> card(BuildContext ctx) => leveled(level: 2);

  /// 部件浮起投影（level 8：按钮、底部导航浮层）—— 保留同名 API 以兼容旧调用
  static List<BoxShadow> lifted(BuildContext ctx) => leveled(level: 8);
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
/// 用于存放 JWT 凭证，退出登录时清除。
class SecureKeys {
  SecureKeys._();

  /// access token（JWT），请求头 Authorization: Bearer xxx
  static const String accessToken = 'auth_access_token';

  /// refresh token，用于 access token 过期后换取新 token
  static const String refreshToken = 'auth_refresh_token';
}
