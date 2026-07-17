import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimens.dart';
import '../../core/theme/app_motion.dart';

/// 骨架占位行
class ZySkeletonLine extends StatelessWidget {
  const ZySkeletonLine({
    super.key,
    this.height = 12,
    this.width = double.infinity,
    this.radius,
  });

  final double height;
  final double width;
  final double? radius;

  @override
  Widget build(BuildContext context) => Semantics(
        label: '内容加载中',
        child: AnimatedOpacity(
          opacity: 1,
          duration: AppMotion.fast(context),
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: AppColors.paperStrong,
              borderRadius:
                  BorderRadius.circular(radius ?? AppDimens.radiusStatus),
            ),
          ),
        ),
      );
}

/// 骨架占位块
class ZySkeletonBlock extends StatelessWidget {
  const ZySkeletonBlock({
    super.key,
    required this.height,
    this.width = double.infinity,
    this.radius = AppDimens.radiusCard,
  });

  final double height;
  final double width;
  final double radius;

  @override
  Widget build(BuildContext context) => Semantics(
        label: '内容加载中',
        child: AnimatedOpacity(
          opacity: 1,
          duration: AppMotion.fast(context),
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: AppColors.paperStrong,
              borderRadius: BorderRadius.circular(radius),
            ),
          ),
        ),
      );
}

/// 与临床记录行三列结构一致的加载占位。
class ZyRecordSkeleton extends StatelessWidget {
  const ZyRecordSkeleton({
    super.key,
    this.itemCount = 3,
  }) : assert(itemCount > 0, 'itemCount must be greater than zero.');

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      liveRegion: true,
      label: '记录加载中',
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: List<Widget>.generate(
            itemCount,
            (int index) => _RecordSkeletonRow(
              showDivider: index < itemCount - 1,
            ),
          ),
        ),
      ),
    );
  }
}

class _RecordSkeletonRow extends StatelessWidget {
  const _RecordSkeletonRow({required this.showDivider});

  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.symmetric(vertical: AppDimens.grid3),
      decoration: BoxDecoration(
        border: showDivider
            ? const Border(
                bottom: BorderSide(color: AppColors.rule, width: 1),
              )
            : null,
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 76,
            child: Align(
              alignment: Alignment.topLeft,
              child: ZySkeletonLine(width: 48),
            ),
          ),
          SizedBox(width: AppDimens.grid2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                ZySkeletonLine(height: 14),
                SizedBox(height: AppDimens.grid2),
                FractionallySizedBox(
                  widthFactor: 0.72,
                  alignment: Alignment.centerLeft,
                  child: ZySkeletonLine(),
                ),
              ],
            ),
          ),
          SizedBox(width: AppDimens.grid2),
          SizedBox(
            width: 72,
            child: Align(
              alignment: Alignment.topRight,
              child: ZySkeletonLine(width: 48),
            ),
          ),
        ],
      ),
    );
  }
}
