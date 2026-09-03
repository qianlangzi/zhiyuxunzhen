/// 药品库条目模型（对齐后端 DrugListVO），供训练中心 / 药品库页共用。
class DrugItem {
  final int id;
  final String genericName;
  final String tradeName;
  final String englishName;
  final String category;
  final String department;
  final String dosageForm;
  final bool isOtc;

  const DrugItem({
    required this.id,
    required this.genericName,
    this.tradeName = '',
    this.englishName = '',
    required this.category,
    required this.department,
    this.dosageForm = '',
    this.isOtc = false,
  });

  factory DrugItem.fromJson(Map<String, dynamic> json) {
    return DrugItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      genericName: json['genericName'] as String? ?? '未命名药品',
      tradeName: json['tradeName'] as String? ?? '',
      englishName: json['englishName'] as String? ?? '',
      category: json['category'] as String? ?? '其他',
      department: json['department'] as String? ?? '',
      dosageForm: json['dosageForm'] as String? ?? '',
      isOtc: (json['isOtc'] as num?)?.toInt() == 1,
    );
  }
}
