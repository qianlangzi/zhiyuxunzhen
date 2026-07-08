/// 通用格式化工具
class Formatters {
  Formatters._();

  /// 难度映射为中文标签
  static String difficultyLabel(String raw) {
    switch (raw) {
      case 'basic':
      case '基础':
        return '基础';
      case 'standard':
      case '标准':
        return '标准';
      case 'advanced':
      case '进阶':
        return '进阶';
      case 'expert':
      case '高阶':
        return '高阶';
      default:
        return raw;
    }
  }

  /// 难度颜色权重（0~1）
  static double difficultyWeight(String raw) {
    switch (raw) {
      case 'basic':
      case '基础':
        return 0.25;
      case 'standard':
      case '标准':
        return 0.5;
      case 'advanced':
      case '进阶':
        return 0.75;
      case 'expert':
      case '高阶':
        return 1.0;
      default:
        return 0.5;
    }
  }

  /// 百分比格式化
  static String percent(num value, {int decimals = 0}) {
    return '${value.toStringAsFixed(decimals)}%';
  }

  /// 简化数字：>=1000 显示为 1k+
  static String compactNumber(num value) {
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}k+';
    }
    return value.toString();
  }
}
