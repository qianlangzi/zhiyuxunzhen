# 注册功能、项目启动与 GitHub 提交指南

> 更新时间：2026-07-21
>
> 适用项目：`qianlangzi/zhiyuxunzhen`
>
> 当前分支：`main`

## 1. 这次已经完成了什么

### 1.1 Flutter 移动端

- 登录页增加了“注册账号”入口。
- 新增独立注册页面，可以选择“学生”或“教师”。
- 学生和教师都需要填写真实姓名、账号、手机号、短信验证码、密码和确认密码。
- 教师还必须填写教师资质编号和科室。
- 注册成功后不会直接登录，而是返回登录页并自动填入刚注册的账号。
- 密码要求为 8 至 64 位，并且必须同时包含字母和数字。
- Flutter 只允许学生和教师进入移动端；管理角色不能误进入移动端页面。

### 1.2 Spring Boot 后端

- 新增注册接口：`POST /api/v1/auth/register`。
- 增加账号和手机号唯一性校验，避免重复注册。
- 密码使用 BCrypt 哈希保存，不在数据库中保存明文密码。
- 学生注册后为正常学生账号：`role=0`、`auditStatus=0`。
- 教师注册后为待审核账号：`role=1`、`auditStatus=1`。
- 待审核教师登录时返回业务码 `2004`，不能提前进入教师端。
- 教师资质编号和科室会持久化到 `sys_user`，并由管理审核接口返回。
- 新增可重复执行的 Flyway 迁移：`V2__registration_teacher_profile.sql`。
- 注册成功不签发 Token，防止教师绕过审核直接登录。

### 1.3 已验证结果

- Spring Boot 完整测试：71 个通过。
- 注册相关后端测试：23 个通过。
- Flutter 完整测试：132 个通过。
- Flutter 静态分析：0 个问题。
- Flyway V1、V2 已在 MySQL 8.0 成功执行。
- Android Debug APK 已成功构建并安装到模拟器。
- 真实端到端流程已通过：获取验证码 -> 教师注册 -> 待审核登录被拒绝 -> 管理员读取资质 -> 审核通过 -> 教师成功登录。
- 验证过程中创建的临时账号和审核记录已经清理。

## 2. 注册逻辑现在如何闭环

### 学生流程

1. 在登录页点击注册。
2. 选择学生身份，填写资料并获取验证码。
3. 后端校验验证码、账号、手机号和密码。
4. 创建学生账号。
5. 返回登录页，使用账号和密码登录。
6. 后端签发 Token，Flutter 根据真实角色进入学生端。

### 教师流程

1. 在登录页点击注册。
2. 选择教师身份，并填写资质编号和科室。
3. 后端创建待审核教师账号，但不签发 Token。
4. 审核通过前，教师登录会收到“待审核”提示。
5. 管理员通过后，教师才能登录并进入教师端。

## 3. 目前明确没有做什么

- 没有接入阿里云、腾讯云等真实短信供应商。开发环境可以完成验证码流程，但不能当作生产短信系统。
- 没有实现教师证件图片或 PDF 上传，目前只保存资质编号和科室。
- Vue 管理端仍使用 Mock 数据，没有连接教师审核接口。按当前决定，这部分先不继续做。
- 学生所属班级不会在公开注册时自行选择，仍应由学校或管理员分配。
- 还没有在 Android 真机上完成最终验收；当前验证环境是 Android 模拟器。

## 4. 以后如何启动后端和手机模拟器

### 第一步：启动 Docker Desktop

先打开 Docker Desktop，等它显示 Engine 已正常运行。

### 第二步：启动后端、AI 和依赖服务

在 PowerShell 中执行：

```powershell
cd E:\zhiyu
docker compose up -d --build backend ai
docker compose ps
```

第一条命令进入项目目录；第二条会启动并构建后端、AI、MySQL、Redis、Milvus 等依赖；第三条用来确认容器是否正常运行。

检查后端：

```powershell
Invoke-WebRequest http://localhost:8080/api/v1/health
```

看到成功响应后再启动 App。查看后端日志可以执行：

```powershell
docker compose logs -f backend
```

按 `Ctrl+C` 只会退出日志查看，不会关闭后端。

### 第三步：启动 Android 模拟器

1. Android Studio 打开 `E:\zhiyu\mobile`，不要只打开整个 `E:\zhiyu`。
2. 打开 Device Manager，点击目标虚拟手机右侧的启动按钮。
3. 等虚拟手机完全进入桌面。
4. Android Studio 顶部运行配置选择 Flutter 的 `main.dart`，设备选择刚启动的模拟器。
5. 点击绿色三角运行。

如果绿色三角仍卡住，直接在 PowerShell 中运行，错误会显示得更清楚：

```powershell
cd E:\zhiyu\mobile
flutter devices
flutter pub get
flutter run -d emulator-5554
```

如果 `flutter devices` 显示的设备编号不是 `emulator-5554`，把最后一条命令中的编号换成实际编号。

Android 模拟器访问电脑后端必须使用 `10.0.2.2`，不能使用 `localhost`。项目默认配置已经是：

```text
后端：http://10.0.2.2:8080
AI：http://10.0.2.2:8000
```

### 第四步：停止服务

```powershell
cd E:\zhiyu
docker compose down
```

不要使用 `docker compose down -v`，因为 `-v` 会删除数据库卷，可能清空本地数据。

## 5. 把当前项目更新到 GitHub

当前仓库已经正确关联：

```text
origin = https://github.com/qianlangzi/zhiyuxunzhen.git
分支 = main
上游分支 = origin/main
本地 main 比 origin/main 领先 5 个提交
```

这 5 个本地提交是此前的设计文档和本地工作树配置记录：

```text
5066b80 docs: clean integration design formatting
38c464f docs: design Flutter mobile full-stack integration
9d9072c chore: ignore local worktrees
12cb1b3 docs: plan mobile real API integration
c327b94 docs: design mobile real API integration
```

因此最后执行 `git push origin main` 时，Git 会把这 5 个已有本地提交和你接下来创建的新提交一起上传。这是正常的，不是重复提交代码。

工作区中改动很多。不要执行 `git add .`，也不要提交 `.env` 和 `logs/`。下面的命令会提交当前已经实现的 AI、后端、数据库、Flutter 和说明文档，同时不包含暂缓的 Vue 管理端。

### 5.1 先查看改动

```powershell
cd E:\zhiyu
git status
git diff --stat
```

- `git status`：查看哪些文件被修改、新增或删除。
- `git diff --stat`：只看每个文件大概改了多少，不会提交任何东西。

### 5.2 选择这次要提交的文件

```powershell
git add -- .env.example ai backend deploy mobile docker-compose.yml docs/FLUTTER_MOBILE_FULLSTACK_GUIDE.md docs/REGISTRATION_AND_GITHUB_GUIDE.md
```

`git add` 只是把这些文件放进“待提交区”，还没有上传 GitHub。这里故意没有添加 `.env`、`logs/`、`front/` 和内部计划文档。

### 5.3 提交前复查

```powershell
git status
git diff --cached --stat
git diff --cached
```

- 再次运行 `git status`：确认待提交文件是否正确。
- `git diff --cached --stat`：查看即将提交的文件和改动量。
- `git diff --cached`：查看即将提交的具体代码。内容较多时按空格翻页，按 `q` 退出。

如果发现不该提交的文件，可以把它移出待提交区，例如：

```powershell
git restore --staged 不该提交的文件路径
```

这条命令不会删除文件，也不会丢失你的代码，只是取消本次选中。

### 5.4 创建本地提交

```powershell
git commit -m "feat: complete mobile full-stack flow and registration"
```

`git commit` 会在本地创建一个版本记录。此时 GitHub 还没有更新。

### 5.5 上传到 GitHub

推送前可以再次确认所有尚未上传的本地提交：

```powershell
git log --oneline origin/main..main
```

确认无误后执行：

```powershell
git push origin main
```

`git push` 才会把本地 `main` 的新提交上传到 GitHub。当前分支已经关联 `origin/main`，不需要额外使用 `-u`。

如果 GitHub 要求登录，请使用浏览器授权或 Personal Access Token；GitHub 已经不接受账号密码直接推送代码。

### 5.6 上传后确认

```powershell
git status
git log -1 --oneline
```

理想情况下，`git status` 会显示本次已提交路径没有待提交改动；`git log -1 --oneline` 会显示刚才的提交说明。因为本次故意排除了管理端和内部计划文件，仓库仍可能显示那些未提交项，这是正常的。

## 6. 重要安全提醒

- 永远不要提交 `.env`，里面可能包含数据库密码、JWT 密钥和第三方 API Key。
- `.env.example` 只能放示例值，不能放真实密钥。
- 不要执行 `git push --force`，它可能覆盖 GitHub 上的历史。
- 不要为了“变干净”执行 `git reset --hard`，它可能永久丢失尚未提交的代码。
- 正式上线前必须更换示例 `JWT_SECRET`、`AI_INTERNAL_TOKEN`，并接入真实短信供应商。
