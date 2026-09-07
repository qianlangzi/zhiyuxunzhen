# SP 病例多模态增强 实现说明（v1.0 · 2026-09-06）

> 目标：教师构建病例时可上传影像/报告素材（X光/CT/化验单/音频/视频），学生问诊时 AI 把材料作为检查报告卡发给医学生；教师有 AI 素材推荐防漏传；已发布 SP 支持二次编辑重新上架；每日病历同步支持患者影像展示。

---

## 一、设计原则：零迁移、全复用

- **不动表结构**：素材挂在 `sp_case_config.presetExams` JSON 条目内（`result.imageUrls`），与既有 `result.kind=image + imageKeys`（AI 中台教材配图）机制兼容并存，老数据完全不受影响。
- **复用已有链路**：
  - 存储：复用问诊影像通道（`uploads/multimodal/` + `/uploads/**` 静态映射）
  - 下发：复用检查报告卡确定性分发（`ai/app/services/exam_dispatch.py`，规则匹配命中才下发，零幻觉）
  - 渲染：问诊聊天已支持 ecg/lab/image 三态报告卡，本次扩展 `imageUrls` 直连渲染

## 二、多端改动清单

| 端 | 改动 | 位置 |
| --- | --- | --- |
| 教师端·编辑 | 检查项加「传图」：选图上传 → 缩略图预览（点替换/长按删除），保存时写入 `result.imageUrls` | `sp_config_screen.dart` |
| 教师端·AI推荐 | 「AI 建议材料清单」：按病例诊断推荐 4-8 条材料（必备/建议/可选 + 理由），一键加入检查项，防漏传 | 同上 + 新 AI 接口 |
| 教师端·二次编辑 | 已发布病例「查看」→「二次编辑」，保存 version+1 自动更新广场内容 | `my_cases_screen.dart`（后端 update/publish-to-market 原生支持） |
| 学生端·问诊 | 检查报告卡新增「患者影像资料」条（教师上传素材，URL 直连，点击全屏缩放） | `chat_room_screen.dart` |
| 学生端·每日病历 | 书写工坊病例卡新增「患者影像资料」条（只给图不给结论，防剧透诊断） | `mr_workshop_screen.dart` |
| AI 中台 | `exam_dispatch` 透传 `imageUrls`；新增 `/teacher/case/material_advice`（teacher 分组 action=material_advice，纯归纳不引 RAG 防编造） | `exam_dispatch.py` / `api/teacher.py` / `prompts` / `gateway_features.py` |
| 后端 | `POST /api/v1/teacher/cases/media`（图片/PDF/MP3/MP4 ≤20MB）；`GET /api/v1/teacher/ai/material-advice/{caseId}`；每日病历 detail 返回 `exams:[{name,imageUrls}]` | `TeacherCaseController` / `TeacherAiController` / `DailyMrServiceImpl` |

## 三、素材数据流（教师上传 → 学生看到）

```
教师编辑病例 → 检查项点「传图」→ POST /teacher/cases/media
  → 存 uploads/multimodal/case_*.png → 返回 /uploads/multimodal/xxx.png
  → 保存病例时写入 presetExams[i].result.imageUrls=[url]
  → 学生问诊提到该检查（规则匹配命中）
  → AI exam_dispatch.build_report 下发报告卡（kind=image, imageUrls=[url], conclusion=mark 结果）
  → 问诊聊天渲染「患者影像资料」条 → 点击全屏

每日病历：GET /daily-cases/mr/{scheduleId} → exams=[{name, imageUrls}]
  → 工坊页病例卡「患者影像资料」条（不含结论文本，防剧透）
```

## 四、AI 素材推荐说明

- 输入：病例标题/科室/主诉/真实诊断/现病史 + 已配置检查项
- 输出：`suggestions:[{item, kind(image/pdf/audio/video/text), reason, priority(1必备2建议3可选)}] + summary`
- 防幻觉设计：纯归纳型 prompt，只基于病例自身信息推荐；已配置项自动去重；提示词与基线走配置中心可热调

## 五、验证记录（2026-09-06）

- 后端 `mvn compile` / `mvn package` 通过；AI `py_compile` 通过；移动端 `dart analyze` 0 error 0 warning
- 端到端冒烟见文末「部署与验证」

## 六、部署与验证

1. 后端：`mvn package` → `docker-compose restart backend`（Flyway 无新迁移，本次零表变更）
2. AI：`ai` 容器 bind mount 自动生效；**`ai-worker` 若也用到 exam_dispatch 需 `docker-compose build ai-worker && docker-compose up -d ai-worker`**
3. 移动端热重启
4. 冒烟：
   - `curl localhost:18000/teacher/case/material_advice -H "X-Internal-Token: dev-internal-token" -H "Content-Type: application/json" -d '{"title":"急性脓胸","department":"呼吸内科","hiddenDisease":"脓胸","complaint":"左侧胸痛伴发热2周"}'`
   - 教师端建病例 → 检查项传图 → 保存 → 学生问诊提"胸片" → 聊天内出现「患者影像资料」
   - 每日病历工坊页看「患者影像资料」条
5. 已知边界：素材 URL 是本机 uploads，**生产部署需换对象存储或确保 uploads 卷持久化**（当前 compose 已把 ./data 挂载，uploads 目录跟随容器工作目录，建议后续统一到 minio）
