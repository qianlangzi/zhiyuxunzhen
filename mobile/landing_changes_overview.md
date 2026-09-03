# 落地「用户看不懂」审查修改 · 变更概览

> 将 `frontend_design_review.md`（P0 + P1）中识别出的理解障碍落地到代码。
> Flutter 与原型 `student.html` / `teacher.html` 文案同源，已同步修改。
> 验证：`flutter analyze` error = **0**（剩余 390 条均为既有 info 级 lint）。

## P0 — 必须修

### P0-1 OSCE 雷达图例/口径补齐 6 维
- `lib/.../student/result/osce_result_screen.dart`：图例由 4 项补到 6 项（病史采集 / 诊断逻辑 / 沟通技巧 / 人文关怀 / 检查决策 / 文书规范）；doc 注释「四维」→「六维」；副标题「OSCE 评估」→「OSCE 临床考核」。
- `lib/.../teacher/dashboard/dashboard_screen.dart`：教师端「OSCE 四维均分」→「六维均分」，补 检查决策 80.8 / 文书规范 81.6 两行（雷达本就 6 轴）。
- `student.html` / `teacher.html`：OSCE「四维」→「六维」，学生端雷达图例补 检查决策 / 文书规范。

### P0-2 SP / OSCE 首次出现加中文注释
- `lib/.../teacher/case_config/sp_config_screen.dart`：SP 配置台顶部加说明条「SP = 标准化病人（Standardized Patient）：模拟真实患者……」。
- `student.html`（chat_room）：问诊气泡 `SP · 时间` → `患者 · 时间`（×4）。
- `teacher.html`：SP 配置台加同样中文说明条。
- 另：`chat_room_screen.dart`「导师提示」→「AI 导师提示」（说明提示来自 AI，非真人导师）。

### P0-3 苏格拉底等级说明
- `lib/.../student/tree/thinking_tree_screen.dart`：「苏格拉底式反思 · 一级」→「苏格拉底式提示（轻度）」；「查看标准路径 · 三级」→「标准路径（完整答案）」。
- `student.html`：对齐为「苏格拉底式提示（轻度）」。

## P1 — 建议修

### P1-1 检查费用加「模拟不扣费」
- `thinking_tree_screen.dart` / `chat_room_screen.dart`：费用卡加「模拟不扣费」说明（卫生经济学模拟，不真实扣费）。

### P1-2 诊断节点状态颜色语义
- `app_widgets.dart`：新增 `StatusBadgeType.neutral`（灰，ruleSoft / text3），修复「可能性低」误用绿色误导。
- `thinking_tree_screen.dart` / `chat_room_screen.dart`：肺栓塞「可能性低」节点 `ok` → `neutral`。

### P1-3 mock 数据口径自洽
- `student_home_screen.dart`：热力图「365 天」→「近半年 182 天」（网格实为 26×7 = 182 格）；「连续训练 / 天」→「连续训练天数」；每日一例角标「CASE 07.21」→「07.21」（去重编号歧义）。
- `mistakes_screen.dart`：统计区加「示例数据 · 仅展示部分错题」（顶部 17/8/23 与列表仅 4 条不符的口径说明）。
- `student.html`：热力图、streak、每日一例角标同步。

## 未覆盖（P2，低优先级，本次未改）
- 伪造系统状态栏（双时钟）；问诊 Q3 选中「应避免」项变红易被误读；部分图标/字号微调。
- 如需，可下一轮处理。
