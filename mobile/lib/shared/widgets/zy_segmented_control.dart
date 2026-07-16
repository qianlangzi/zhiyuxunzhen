import 'package:flutter/material.dart';

import '../../core/constants/app_dimens.dart';

class ZySegment<T> {
  const ZySegment({required this.value, required this.label, this.icon});

  final T value;
  final String label;
  final IconData? icon;
}

class ZySegmentedControl<T> extends StatelessWidget {
  const ZySegmentedControl({
    super.key,
    required this.value,
    required this.segments,
    required this.onChanged,
  });

  final T value;
  final List<ZySegment<T>> segments;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<T>(
      segments: segments
          .map((ZySegment<T> item) => ButtonSegment<T>(
                value: item.value,
                label: Text(item.label),
                icon: item.icon == null ? null : Icon(item.icon),
              ))
          .toList(),
      selected: <T>{value},
      onSelectionChanged: (Set<T> values) => onChanged(values.first),
      showSelectedIcon: false,
      style: ButtonStyle(
        shape: WidgetStatePropertyAll<OutlinedBorder>(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimens.radiusControl),
          ),
        ),
      ),
    );
  }
}
