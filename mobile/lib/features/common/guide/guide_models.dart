import 'package:flutter/material.dart';

/// 新手指引 · 数据模型
///
/// 一个 [GuideTour] 是一条引导流程（对应一个 Tab 页或一次开屏速览），
/// 由若干 [GuideStep] 组成；每步要么高亮页面上的真实控件（[GuideStep.anchor]），
/// 要么退化成一张居中的「概念卡」（anchor 为空），用来讲解看不见的隐藏手势。

/// 引导里要演示的手势类型
///
/// 这些是新手最难自己发现的交互，用循环动画演示比文字更直观。
enum GuideGesture {
  /// 不演示
  none,

  /// 轻点
  tap,

  /// 长按
  longPress,

  /// 按住上下拖动（排序 / 手柄）
  drag,

  /// 向左滑动
  swipeLeft,

  /// 向右滑动
  swipeRight,

  /// 双指张开 / 捏合（缩放）
  pinch,

  /// 底部弹层向下拖动关闭
  sheetDrag,

  /// 下拉刷新
  pullDown,
}

/// 引导步骤
@immutable
class GuideStep {
  const GuideStep({
    required this.title,
    required this.desc,
    this.anchor,
    this.gesture = GuideGesture.none,
    this.circle = false,
    this.tag,
  });

  /// 标题（一句话讲清「这是什么」）
  final String title;

  /// 说明（讲清「怎么用」以及「为什么值得用」）
  final String desc;

  /// 要高亮的控件锚点。为 null 时本步以居中概念卡呈现（不挖洞）
  final String? anchor;

  /// 手势演示动画
  final GuideGesture gesture;

  /// 高亮光圈形状：圆形（图标按钮）还是圆角矩形（卡片 / 区块）
  final bool circle;

  /// 右上角小角标文案，如「隐藏操作」
  final String? tag;

  bool get hasGesture => gesture != GuideGesture.none;
}

/// 一条引导流程
@immutable
class GuideTour {
  const GuideTour({
    required this.id,
    required this.steps,
    this.intro = false,
  });

  /// 唯一 id，同时用作「已完成」持久化标记
  final String id;

  final List<GuideStep> steps;

  /// 是否为开屏「隐藏手势速览」（无锚点、居中展示）
  final bool intro;
}
