# 智愈寻真移动端「临床刊物」重构实施计划

日期：2026-07-16

设计规格：`docs/superpowers/specs/2026-07-16-zhiyu-mobile-clinical-ledger-redesign-design.md`

目标：在不改动业务模型、Repository、角色守卫和后端接口的前提下，将全部 Flutter 学生端与教师端重构为已确认的「临床刊物 × 精密工作台」视觉，并交付可安装的 Android Release APK。

## 1. 执行约束

- 只修改 `mobile/` 和本计划明确列出的文档。
- 不执行 `git push`、Release 发布、APK 上传或任何外部文件传输。
- 本地提交只包含当前任务的精确路径，不使用 `git add .` 或 `git add -A`。
- 不回退工作区已有修改；当前 7 个 Flutter 生成文件仅被标记为修改且标准化 diff 为空，实施提交不得包含它们。
- `.superpowers/brainstorm/` 为临时设计预览，不进入产品提交。
- Flutter SDK 通过已缓存的 Docker 镜像运行；本机没有可用的 Flutter/ADB。
- 每个任务遵循测试先行：先更新或新增会失败的断言，再实现，再运行目标测试和静态分析。

## 2. 架构决策

1. 保留 Riverpod、go_router、Repository 和现有模型；本轮只改变主题、共享 UI 原语和页面组合。
2. 使用现有 Material 图标，不引入第二套图标库。
3. 通过 `ClinicalHeader`、`ClinicalSectionHeader`、`ClinicalRecordRow` 和 `ClinicalEvidenceAxis` 建立新语言，不扩张万能卡片参数；两个标题组件共置于一个聚焦页眉结构的文件。
4. 页面标题使用 Android 系统衬线族并回退到系统无衬线；正文和控件继续使用系统无衬线，不增加大型中文字体资源。
5. 先用 Flutter Web 做多尺寸视觉检查，最终以 Android Release APK 构建结果为交付依据。
6. Release APK 暂用仓库现有 debug signing，仅用于本地安装验收，不用于应用商店发布。

## 3. 依赖图

```text
Task 0 Android 构建基线
Task 1 视觉 tokens 与主题
        |
        v
Task 2 临床共享原语 --> Task 3 现有共享组件
        |                       |
        +-----------+-----------+
                    v
              Task 4 登录与双角色壳
                    |
          +---------+---------+
          v                   v
   Tasks 5-7 学生端      Tasks 8-10 教师端
          +---------+---------+
                    v
          Task 11A/11B 状态与响应式
                    v
             Task 12 浏览器视觉验收
                    v
             Task 13 Release APK
```

共享基础完成后，学生端 Tasks 5-7 与教师端 Tasks 8-10 可以并行，但同一测试文件只能由一个任务负责人修改。

## 4. 任务清单

### Task 0：建立可移植 Android 构建基线

**文件：**

- `mobile/android/gradle.properties`
- `mobile/android/app/build.gradle.kts`
- `mobile/android/app/src/main/AndroidManifest.xml`
- `mobile/Dockerfile`（仅在 NDK 不能按需安装时修改）
- `mobile/android/app/src/main/res/mipmap-*`（机械生成的启动图标资源）

**实施：**

- 移除只适用于原作者电脑的 `E:\Java` 与本机代理硬编码；代理应由用户级 Gradle 配置或构建环境提供。
- 保留 Java 17、现有 applicationId 与本地验收用 debug signing。
- 将 Android 应用名称从 `zhiyu` 改为「智愈寻真」。
- 使用现有 `assets/images/brand-logo.png` 生成 Android 启动图标尺寸，不重绘、不改色；只增加系统图标要求的安全留白。
- 若镜像不能按需安装 `30.0.15729638` NDK，再在 Dockerfile 中显式预装并重建工具镜像。

**验收：**

- Docker 中 Gradle 能找到容器 Java 和依赖源。
- `flutter build apk --debug` 成功，且 Android manifest 合并无错误。
- 安装包名称和启动图标均为「智愈寻真」品牌，不再使用 Flutter 默认图标。
- 未引入 keystore、密码或签名秘密。

**验证：**

```powershell
docker compose --profile mobile run --rm mobile sh -lc "flutter build apk --debug"
```

**依赖：** 无。
**规模：** M，3 个手写配置文件、1 个条件配置和一组机械图标资源。

### Task 1：更新视觉 tokens、排版和 Material 主题

**文件：**

- `mobile/lib/core/constants/app_colors.dart`
- `mobile/lib/core/constants/app_dimens.dart`
- `mobile/lib/core/constants/app_text_styles.dart`
- `mobile/lib/core/theme/app_theme.dart`
- `mobile/test/core/theme/app_theme_test.dart`

**测试先行：**

- 将主题测试改为断言规格中的中性纸色、行动蓝、风险红、通过绿、4/8/16 圆角层级和非胶囊按钮。
- 增加标题使用系统衬线族、正文使用系统无衬线以及 1.3 倍字体缩放可用的断言。

**实施：**

- 替换旧深青主导色，建立 `paper / ink / graphite / rule / action / risk / success` 语义 tokens。
- 移除未打包且 Android 不保证存在的 `PingFang SC` 硬编码；标题尝试系统衬线族并提供无衬线回退，正文统一系统无衬线。
- 收紧标题字重，保留固定字号和 0 字距。
- 更新 AppBar、按钮、输入、分隔线、底栏、弹层、焦点、错误和选中状态。

**验收：**

- 主题测试通过；普通卡片无阴影，按钮和输入不是 pill。
- 文本与背景满足规格对比度，颜色不承担唯一状态含义。

**验证：**

```powershell
docker compose --profile mobile run --rm mobile sh -lc "flutter test test/core/theme/app_theme_test.dart && flutter analyze"
```

**依赖：** 无。
**规模：** M，5 个文件。

### Task 2：新增临床刊物共享原语

**文件：**

- `mobile/lib/shared/widgets/clinical_headers.dart`（新增，包含 `ClinicalHeader` 与 `ClinicalSectionHeader`）
- `mobile/lib/shared/widgets/clinical_record_row.dart`（新增）
- `mobile/lib/shared/widgets/clinical_evidence_axis.dart`（新增）
- `mobile/lib/shared/widgets/widgets.dart`
- `mobile/test/shared/widgets/clinical_primitives_test.dart`（新增）

**测试先行：**

- 断言页眉在窄屏和 1.3 倍字体下不溢出。
- 断言记录行整行可点击、触控高度至少 52px、状态有文字语义。
- 断言证据轴可表达普通、缺失、风险与完成节点，且颜色不是唯一提示。

**实施：**

- 页眉只承载产品名、页面标题、日期/身份和可选单一动作；分区标题使用标题、可选说明和 1px 下规则。
- 记录行采用编号/时间、主内容、状态三列，宽度不足时允许主内容换行。
- 证据轴使用 1px 规则与小节点，不使用粗彩色侧边条。

**验收：**

- 三个组件接口聚焦领域语义，不暴露大量样式配置。
- 360px 宽度、长中文和字体放大时无异常。

**验证：**

```powershell
docker compose --profile mobile run --rm mobile sh -lc "flutter test test/shared/widgets/clinical_primitives_test.dart && flutter analyze"
```

**依赖：** Task 1。
**规模：** M，5 个文件。

### Task 3：收敛现有共享组件

**文件：**

- `mobile/lib/shared/widgets/zy_app_bar.dart`
- `mobile/lib/shared/widgets/zy_bottom_bar.dart`
- `mobile/lib/shared/widgets/zy_card.dart`
- `mobile/lib/shared/widgets/zy_chip.dart`
- `mobile/test/shared/widgets/zy_bottom_bar_test.dart`

**测试先行：**

- 更新底栏选中态测试：底部指示线、图标与中文标签，不使用大块胶囊背景。
- 增加 44px 触控、Semantics 名称和长标签不溢出的断言。

**实施：**

- AppBar 对齐新的标题节奏。
- BottomBar 使用稳定高度、图标+短中文和底部选中线。
- Card 仅保留真正独立对象的细边框/小圆角；Chip 收敛为小型状态或筛选控件。

**验收：**

- 无卡片套卡片；未选中导航不使用高饱和色。
- 原有调用方保持可编译，迁移期不做无关 API 删除。

**验证：**

```powershell
docker compose --profile mobile run --rm mobile sh -lc "flutter test test/shared/widgets/zy_bottom_bar_test.dart && flutter analyze"
```

**依赖：** Tasks 1-2。
**规模：** M，5 个文件。

### Task 4：重构登录与双角色应用壳

**文件：**

- `mobile/lib/features/auth/login_page.dart`
- `mobile/lib/features/student/student_shell.dart`
- `mobile/lib/features/teacher/teacher_shell.dart`
- `mobile/test/features/auth/login_page_test.dart`
- `mobile/test/routes/role_routing_test.dart`

**测试先行：**

- 更新登录页文案、Logo、分段身份、字段错误、加载与提交行为断言。
- 保留学生、教师、管理员分流和跨角色访问守卫测试。

**实施：**

- 登录页改为品牌区、简短说明和单一表单，不使用身份卡或营销区。
- 两端 Shell 使用新的底栏与页面背景，保留现有路径和切换行为。
- 将旧代码和测试中的「知语寻真」统一为已确认规格、README 与 MaterialApp 使用的「智愈寻真」，包括 Logo Semantics。

**验收：**

- `student01 / 123456` 与 `teacher01 / 123456` 可进入对应工作区。
- 管理角色仍提示使用 Web 管理端；路由行为不变。

**验证：**

```powershell
docker compose --profile mobile run --rm mobile sh -lc "flutter test test/features/auth/login_page_test.dart test/routes/role_routing_test.dart && flutter analyze"
```

**依赖：** Tasks 1-3。
**规模：** M，5 个文件。

### Task 5：重构学生首页与病例发现流程

**文件：**

- `mobile/lib/features/student/home/student_home_page.dart`
- `mobile/lib/features/student/cases/cases_list_page.dart`
- `mobile/lib/features/student/cases/case_detail_page.dart`
- `mobile/test/features/student/student_home_cases_test.dart`（新增）

**测试先行：**

- 学生首页必须出现当前病例、病例编号、临床证据轴和唯一「继续完成问诊」主操作。
- 病例列表保持搜索/筛选/进入详情；详情保持患者概况、目标和底部开始操作。
- 为 `CaseRepository.daily()` 的病例 ID 在详情/问诊展示层提供兼容解析，避免首页 CTA 落入「病例不存在」；不改变 Repository 合同。
- 360/390/430 宽度和 1.3 倍字体无溢出。

**实施：**

- 首页用病例记录与证据轴替换卡片式统计。
- 列表和详情迁移为刊物式记录行、细线分区和稳定操作栏。
- 模型没有持久化剩余进度和完整人口学字段，首版只显示真实的预计用时、摘要和可推导训练阶段，不伪造年龄、性别或倒计时。

**验收：**

- 学生可从首页或病例列表进入详情和问诊。
- 首屏没有等宽指标卡、渐变或无关数据图。

**验证：**

```powershell
docker compose --profile mobile run --rm mobile sh -lc "flutter test test/features/student/student_home_cases_test.dart && flutter analyze"
```

**依赖：** Task 4。
**规模：** M，4 个文件。

### Task 6：重构问诊、能力反馈与错题复盘

**文件：**

- `mobile/lib/features/student/chat/chat_room_page.dart`
- `mobile/lib/features/student/feedback/feedback_page.dart`
- `mobile/lib/features/student/feedback/mistakes_page.dart`
- `mobile/test/features/student/chat_room_page_test.dart`
- `mobile/test/features/student/student_feedback_review_test.dart`（新增）

**测试先行：**

- 保留三种问诊模式、消息发送、滚动、键盘安全和导师提示测试。
- 反馈必须先显示结论和证据；复盘项显示错误依据、状态和下一步。

**实施：**

- 压缩患者摘要，统一消息与证据轴语言。
- 将反馈维度和复盘项改为规则行与可操作记录，删除装饰图表/卡片堆叠。

**验收：**

- 问诊主要交互完整，输入区不被安全区域或键盘遮挡。
- 反馈和复盘仍能跳转到现有目标页面。

**验证：**

```powershell
docker compose --profile mobile run --rm mobile sh -lc "flutter test test/features/student/chat_room_page_test.dart test/features/student/student_feedback_review_test.dart && flutter analyze"
```

**依赖：** Task 5。
**规模：** M，5 个文件。

### Task 7：重构学生个人页与训练热力图

**文件：**

- `mobile/lib/features/student/profile/student_profile_page.dart`
- `mobile/lib/features/student/profile/training_activity.dart`
- `mobile/lib/shared/widgets/zy_activity_heatmap.dart`
- `mobile/test/shared/widgets/zy_activity_heatmap_test.dart`
- `mobile/test/features/student/student_profile_clinical_test.dart`（新增）

**测试先行：**

- 保留 91 个日期单元、强度、点击详情、连续训练和三种手机宽度测试。
- 确保热力图只出现在学生个人页，且不是厚重卡片。

**实施：**

- 身份、学习概况、热力图和账号操作按刊物式分区重排。
- 热力图颜色迁移到新语义色系，保持小方格和固定密度。

**验收：**

- 训练数据与点击行为不变，个人页无横向溢出。
- 退出登录仍有效。

**验证：**

```powershell
docker compose --profile mobile run --rm mobile sh -lc "flutter test test/shared/widgets/zy_activity_heatmap_test.dart test/features/student/student_profile_clinical_test.dart && flutter analyze"
```

**依赖：** Task 4。
**规模：** M，5 个文件。

### Task 8：重构教师概览与批阅主流程

**文件：**

- `mobile/lib/features/teacher/overview/teacher_overview_page.dart`
- `mobile/lib/features/teacher/review/review_page.dart`
- `mobile/lib/features/teacher/review/review_detail_sheet.dart`
- `mobile/test/features/teacher/teacher_overview_review_test.dart`（新增）

**测试先行：**

- 概览必须出现「今天需要处理的事」、紧凑统计带、按「争议 > 待复核 > 其他」排序的批阅登记和唯一主操作；同风险保持 Repository 原顺序。
- 保留详情层拖动、通过、退回、窄屏和字体放大行为测试。
- `ReviewItem` 没有截止时间、完整学生答案或 AI 依据；排序使用「争议 > 待复核 > 其他」，同风险保持 Repository 原顺序，证据轴只组合现有 issue/score/status 和页面局部教师意见，不伪造时间或服务端字段。

**实施：**

- 用记录式登记替换待办卡和三指标卡。
- 详情层用证据轴串联学生答案、AI 依据、教师意见和处理结果。

**验收：**

- 最高风险记录首屏可达，处理后队列状态更新。
- 批阅详情操作不被底部安全区域遮挡。

**验证：**

```powershell
docker compose --profile mobile run --rm mobile sh -lc "flutter test test/features/teacher/teacher_overview_review_test.dart && flutter analyze"
```

**依赖：** Task 4。
**规模：** M，4 个文件。

### Task 9：重构教师病例配置与病例广场

**文件：**

- `mobile/lib/features/teacher/cases/case_config_page.dart`
- `mobile/lib/features/teacher/cases/case_market_page.dart`
- `mobile/test/features/teacher/teacher_cases_clinical_test.dart`（新增）

**测试先行：**

- 保留必填校验、有效标题保存、病例引用和列表操作测试。
- 增加 360px 与 1.3 倍字体下的表单和记录行断言。

**实施：**

- 表单使用分区标题、可见标签与稳定底部保存操作。
- 广场使用记录行展示科室、难度、来源和引用动作。
- 病例广场作为二级页使用 `context.push`，保留明确返回栈，不再用 `context.go` 覆盖当前导航历史。

**验收：**

- 表单校验与引用行为不变；页面不回退成桌面后台表格。

**验证：**

```powershell
docker compose --profile mobile run --rm mobile sh -lc "flutter test test/features/teacher/teacher_cases_clinical_test.dart && flutter analyze"
```

**依赖：** Task 4。
**规模：** S，3 个文件。

### Task 10：重构教师作业与个人页

**文件：**

- `mobile/lib/features/teacher/assignments/assignments_page.dart`
- `mobile/lib/features/teacher/profile/teacher_profile_page.dart`
- `mobile/test/features/teacher/teacher_assignments_profile_test.dart`（新增）

**测试先行：**

- 保留作业创建、校验、本地列表更新、身份信息、导航与退出测试。
- 增加截止时间、提交进度和状态记录行断言。

**实施：**

- 作业按时限和状态排成纵向登记；创建表单使用统一输入与操作栏。
- 教师个人页与学生身份区同源，但仅展示教学概况和账号操作。

**验收：**

- 作业和退出行为不变；教师页不出现学生热力图。

**验证：**

```powershell
docker compose --profile mobile run --rm mobile sh -lc "flutter test test/features/teacher/teacher_assignments_profile_test.dart && flutter analyze"
```

**依赖：** Task 4。
**规模：** S，3 个文件。

### Task 11A：补齐共享状态、中文和可访问性

**文件：**

- `mobile/lib/shared/widgets/zy_empty_state.dart`
- `mobile/lib/shared/widgets/zy_skeleton.dart`
- `mobile/test/widget_test.dart`
- `mobile/test/shared/widgets/shared_states_test.dart`（新增）

**测试先行：**

- 增加空、错、加载、长中文、减少动态效果和关键 Semantics 测试。

**实施：**

- 空状态统一为原因+一个下一步；错误状态提供具体原因与重新加载。
- 骨架与最终记录结构匹配；修正跨页中文和语义缺陷。

**验收：**

- 所有用户可见文字为自然中文，无乱码和无意义英文栏目。
- 颜色不是唯一提示；主要触控目标不小于 44px。

**验证：**

```powershell
docker compose --profile mobile run --rm mobile sh -lc "flutter test test/shared/widgets/shared_states_test.dart test/widget_test.dart && flutter analyze"
```

**依赖：** Tasks 5-10。
**规模：** M，4 个文件。

### Task 11B：响应式与全量页面回归

**文件：**

- `mobile/test/accessibility/responsive_smoke_test.dart`
- `mobile/test/helpers/test_harness.dart`
- `mobile/test/features/student/student_pages_test.dart`
- `mobile/test/features/teacher/teacher_pages_test.dart`

**测试先行：**

- 将全部 14 个主要页面纳入 360×800、1.3 倍字体的溢出冒烟测试。
- 将旧聚合测试收敛为跨页面结构与响应式冒烟，删除已由专用测试覆盖的重复行为断言；更新旧品牌名、旧 CTA 和旧深青视觉结构断言。

**实施：**

- 修正跨页响应式和测试装配问题；页面缺陷回到所属任务文件修复。

**验收：**

- 14 个主要页面在 360/390/430 宽度和 1.3 倍字体下无布局异常。
- 登录、学生、教师和角色路由回归全部通过；`role_routing_test.dart` 只运行不修改，其所有权仍属于 Task 4。

**验证：**

```powershell
docker compose --profile mobile run --rm mobile sh -lc "flutter test test/accessibility/responsive_smoke_test.dart test/features/student/student_pages_test.dart test/features/teacher/teacher_pages_test.dart test/routes/role_routing_test.dart && flutter analyze"
```

**依赖：** Tasks 5-11A。
**规模：** M，4 个回归文件；页面缺陷回到对应任务文件修复。

### Task 12：全量测试与浏览器视觉验收

**预期文件：** 无；发现缺陷时回到所属任务文件修复并重跑相应测试。

**实施：**

- 先运行容器默认命令完成完整 analyze/test；该容器按预期退出，不是预览服务器。
- 启动 Flutter Web 预览，检查登录、学生首页、病例、问诊、反馈、学生个人页、教师概览、作业、批阅和教师个人页。
- 使用 in-app Browser 的 viewport 能力依次设置 360×800、390×844、430×932 和 768×1024，保存并逐张读取截图。
- 使用 Browser console logs 检查错误；使用截图检查文字溢出、底栏遮挡、对比度、触控和选中状态。Semantics 与 44px 触控由 Widget tests 验证，不把 Canvas DOM 当作可访问性证据。
- 对照已确认设计稿进行一次诚实视觉批评并修复实质问题。

**可复现浏览步骤：**

1. 在登录页截取默认状态，检查 Logo、品牌名、身份分段、表单和唯一登录按钮。
2. 使用默认学生演示账号从可见 UI 登录；依次检查首页、病例、问诊、反馈、复盘和我的。
3. 从个人页退出，再使用默认教师演示账号登录；依次检查概览、病例、作业、批阅和我的。
4. 每个角色至少在 390×844 记录完整主流程截图；登录、学生首页和教师概览额外覆盖全部四种 viewport。
5. 截图保存到 `C:\Users\m'm'f\.codex\visualizations\2026\07\16\019f68e8-4565-7d90-82ea-a282b1077e57\mobile-clinical-ledger\<viewport>\<page>.png`，并逐张读回检查。
6. 每个角色流程结束后读取 `tab.dev.logs({levels: ['error', 'warn'], limit: 100})`；任何应用错误必须修复后重跑。

**验收：**

- `flutter analyze` 无问题，完整测试全部通过。
- 截图保留临床刊物结构、行动蓝/风险红/通过绿和证据轴，不出现旧深青卡片仪表盘。
- 浏览器控制台无应用错误。

**验证：**

```powershell
docker compose --profile mobile run --rm mobile
docker compose --profile mobile run --rm -p 8081:8080 mobile sh -lc "flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080"
```

随后在 in-app Browser 打开 `http://localhost:8081`，按上述四种 viewport 截图并读取 `tab.dev.logs`。

**依赖：** Tasks 0-11B。
**规模：** 验证任务。

### Task 13：构建并校验 Android Release APK

**预期源文件：** `mobile/README.md` 仅在需要补充本地构建说明时修改；构建产物不提交 Git。

**实施：**

- 在 Docker Flutter 环境构建通用 Release APK。
- 记录文件路径、字节大小和 SHA-256。
- 使用 Android build-tools 校验 APK 签名、包名、应用名和启动 Activity，并用 `unzip -t` 校验压缩结构。
- 检查 Git 状态，确保 APK、build 输出、临时截图和设计预览未暂存。

**验收：**

- `mobile/build/app/outputs/flutter-apk/app-release.apk` 存在且非空。
- APK 通过 `apksigner verify`、`aapt dump badging` 和 `unzip -t`；当前工作机没有 ADB/模拟器，目标手机安装与冷启动由用户最终确认。
- 提供本地可点击路径、文件大小和 SHA-256。
- 不上传、不发布、不推送。

**验证：**

```powershell
docker compose --profile mobile run --rm mobile sh -lc "flutter build apk --release"
docker compose --profile mobile run --rm mobile sh -lc 'APK=build/app/outputs/flutter-apk/app-release.apk; APKSIGNER=$(find "$ANDROID_HOME/build-tools" -type f -name apksigner | sort | tail -1); AAPT=$(find "$ANDROID_HOME/build-tools" -type f -name aapt | sort | tail -1); "$APKSIGNER" verify --verbose "$APK" && "$AAPT" dump badging "$APK" && unzip -t "$APK"'
Get-FileHash mobile\build\app\outputs\flutter-apk\app-release.apk -Algorithm SHA256
```

**依赖：** Task 12。
**规模：** 构建与交付任务。

## 5. 检查点

### Foundation Checkpoint：Tasks 0-4

- 目标测试通过，Android debug APK 可构建。
- 登录与角色路由保持有效。
- 共享组件已具备新视觉，不再依赖旧卡片语言。

### Feature Checkpoint：Tasks 5-10

- 学生和教师主要流程均可完成。
- 两端共享同一视觉系统，但首屏任务优先级不同。

### Quality Checkpoint：Tasks 11A-12

- 全部测试和 analyze 通过。
- 主要页面在目标宽度完成截图和浏览器运行验证。

### Delivery Checkpoint：Task 13

- Release APK 成功生成并本地校验。
- 最终 Git diff 不包含构建产物、临时预览或无关文件。
- 未发生任何上传或远端推送。

## 6. 风险与缓解

| 风险 | 影响 | 缓解 |
| --- | --- | --- |
| Docker Gradle 受 Windows Java/代理硬编码影响 | APK 无法构建 | Task 0 先移除机器私有配置并构建 debug APK |
| 固定 NDK 未在当前工具镜像预装 | 首次 Android 构建失败或重复下载 | Task 0 先尝试按需安装，必要时在 Dockerfile 固定预装 |
| 系统衬线中文在不同 Android 设备回退不同 | 标题与设计稿不一致 | APK 前用 Android 构建验证；异常时统一回退系统无衬线 |
| 每日病例不在 `byId()` 列表 | 首页进入详情显示不存在 | 仅在详情/问诊展示层兼容 daily ID，不改变 Repository |
| 模型缺少进度、截止时间和完整证据字段 | UI 容易展示伪造数据 | 只组合现有字段与可推导状态，缺失信息不展示 |
| 共享主题与页面并行修改冲突 | 返工或样式漂移 | Tasks 1-4 串行完成后再并行学生/教师页面 |
| 单个页面文件较大 | 修改难审查 | 每次只迁移一个业务流程，测试文件由唯一负责人维护 |
| Web 与 Android 字体/渲染不同 | Web 截图通过但真机观感偏差 | Web 只做布局检查，最终提供 APK 供目标手机验收 |
| 生成插件文件和临时设计稿污染提交 | 无关变更进入历史 | 所有提交使用精确路径，最终检查 staged diff |
| Release 使用 debug signing | 不适合商店分发 | 明确仅用于本地安装；生产签名另立任务并需用户授权 |

## 7. 完成定义

- [ ] 登录、学生端、教师端和共享组件全部采用新临床刊物视觉。
- [ ] 现有 61 个测试及新增测试全部通过。
- [ ] `flutter analyze` 无错误。
- [ ] 14 个主要页面在 360×800、1.3 倍字体下无溢出。
- [ ] 学生证据轴、教师批阅登记和两端唯一主操作符合确认稿。
- [ ] 浏览器完成多尺寸截图和控制台检查。
- [ ] Android Release APK 成功生成，并记录大小与 SHA-256。
- [ ] APK 结构、签名、包名、应用名和启动 Activity 校验通过；真机安装与冷启动明确交由用户验收。
- [ ] 未上传 APK、未执行 `git push`、未发布 Release。
