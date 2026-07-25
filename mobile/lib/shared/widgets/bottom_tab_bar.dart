import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// 底部导航 Tab 定义
class TabItem {
  final String label;
  final String iconPath;
  final IconData icon;

  const TabItem({
    required this.label,
    required this.icon,
    this.iconPath = '',
  });
}

/// 学生端底部导航
class StudentTabBar extends StatelessWidget {
const   StudentTabBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

 static const tabs = [
    TabItem(label: '学习', icon: Icons.home_outlined),
    TabItem(label: '问诊', icon: Icons.chat_bubble_outline),
    TabItem(label: '错题', icon: Icons.description_outlined),
    TabItem(label: '我的', icon: Icons.person_outline),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 78,
      decoration: BoxDecoration(
        color: AppColors.bgOf(context),
        border: Border(top: BorderSide(color: AppColors.ruleOf(context))),
      ),
   padding: EdgeInsets.only(top: 8),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final tab = tabs[i];
          final active = i == currentIndex;
          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onTap(i),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Icon(
                    tab.icon,
                    size: 22,
                    color: active ? AppColors.primaryOf(context) : AppColors.text4Of(context),
                  ),
          SizedBox(height: 4),
                  Text(
                    tab.label,
                    style: TextStyle(
                      fontSize: 10,
                      fontFamily: 'JetBrainsMono',
                      color: active ? AppColors.primaryOf(context) : AppColors.text4Of(context),
                      letterSpacing: 0.04,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// 教师端底部导航
class TeacherTabBar extends StatelessWidget {
const   TeacherTabBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

 static const tabs = [
    TabItem(label: '工作台', icon: Icons.home_outlined),
    TabItem(label: '配置', icon: Icons.tune),
    TabItem(label: '广场', icon: Icons.storefront_outlined),
    TabItem(label: '我的', icon: Icons.person_outline),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 78,
      decoration: BoxDecoration(
        color: AppColors.bgOf(context),
        border: Border(top: BorderSide(color: AppColors.ruleOf(context))),
      ),
   padding: EdgeInsets.only(top: 8),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final tab = tabs[i];
          final active = i == currentIndex;
          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onTap(i),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Icon(
                    tab.icon,
                    size: 22,
                    color: active ? AppColors.primaryOf(context) : AppColors.text4Of(context),
                  ),
          SizedBox(height: 4),
                  Text(
                    tab.label,
                    style: TextStyle(
                      fontSize: 10,
                      fontFamily: 'JetBrainsMono',
                      color: active ? AppColors.primaryOf(context) : AppColors.text4Of(context),
                      letterSpacing: 0.04,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
