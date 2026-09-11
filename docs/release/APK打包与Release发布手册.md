# APK 打包与 GitHub Release 发布手册

> 适用：`E:\zhiyu` monorepo，移动端 `mobile/`。发布顺序**不可颠倒**：先 push `main` 让后端 / AI 上线，再构建 APK 挂 Release。
> 所有命令在 **Windows CMD** 中执行（非 PowerShell / Git Bash）。

---

## 0. 环境前置（一次性确认）

| 项 | 本机现状 | 检查命令 |
|----|---------|---------|
| Flutter | 3.44.5 stable，已在 PATH | `flutter --version` |
| Dart | 3.12.2 | 同上 |
| JDK | 17.0.17 LTS（Gradle 需要） | `java -version` |
| Android SDK | `E:\Android_sdk`（见 `mobile/android/local.properties`） | — |
| GitHub CLI | 2.96.0，**需登录才能发 Release** | `gh auth status` |
| 应用 ID | `com.zhiyu.xunzhen` | — |
| 签名 | release 复用 **debug 签名**（无 keystore） | `mobile/android/app/build.gradle.kts` |

**API 地址默认值是模拟器地址**（`mobile/lib/core/config/api_config.dart` 的 `defaultValue = http://10.0.2.2:18080`）。
构建时**必须**传 `--dart-define=API_BASE_URL=http://8.160.161.158`，漏传的包在真机上完全连不上后端。

---

## 1. 先清掉未提交的改动

```cmd
cd /d E:\zhiyu
git status --short
git add -A
git commit -m "docs(release): 补充 v1.0.2 部署落实验证方式与演示账号冻结说明"
git push origin main
```

`git status --short` 必须为空再进下一步，否则 Release 用的说明文件是旧版。

---

## 2. 等 CI 部署完成（**关键，别跳**）

```cmd
gh auth login
```

交互选项逐项选：

| 提问 | 选择 |
|------|------|
| What account do you want to log into? | **GitHub.com** |
| What is your preferred protocol for Git operations? | **HTTPS** |
| Authenticate Git with your GitHub credentials? | **Yes** |
| How would you like to authenticate GitHub CLI? | **Login with a web browser** |

终端会打印一个 8 位 one-time code（形如 `XXXX-XXXX`）→ 按回车自动开浏览器 → 粘贴 code → **Authorize** → 回到终端显示 `✓ Logged in as qianlangzi`。

```cmd
gh run list --limit 3
gh run watch
```

`deploy.yml` 出现两个 job（`在 CI 构建镜像并推送到 ghcr.io` + `服务器 pull 预构建镜像并重启`）**都绿**才算部署完成。
`ai` 镜像冷构建约 27 分钟；若上一次部署不久，走缓存约 2 分钟内。

> 备选核对方式（electerm SSH 到服务器）：
> ```bash
> cd /opt/zhiyu-new && git log -1 --format='%h %ci %s'
> docker inspect zhiyu-backend --format '{{.State.StartedAt}}'
> ```
> HEAD 应为 `ad6122cb`，StartedAt 晚于 push 时间。

---

## 3. 构建 release APK

**在你自己电脑的终端里跑**（不要交给 AI shell，会撞 Gradle transforms 文件锁）：

```cmd
cd /d E:\zhiyu\mobile
flutter pub get
cd android
gradlew.bat --stop
cd ..
flutter build apk --release --dart-define=API_BASE_URL=http://8.160.161.158
```

- `gradlew.bat --stop` 必须在 `mobile\android` 目录下执行，用于杀掉占用 `build` 目录的 Gradle 守护进程，否则报 `Unable to delete file` / 文件被占用。
- 首次构建约 **5～15 分钟**（跑 R8 混淆 + 打包 3 种 ABI），别中断。
- 成功时最后一行：
  ```
  ✓ Built build\app\outputs\flutter-apk\app-release.apk (23.5MB)
  ```

**若构建报奇怪的缓存错误**，再走一次干净构建（多花几分钟）：

```cmd
cd /d E:\zhiyu\mobile
flutter clean
flutter pub get
flutter build apk --release --dart-define=API_BASE_URL=http://8.160.161.158
```

---

## 4. 改名 + 算校验和

```cmd
cd /d E:\zhiyu\mobile\build\app\outputs\flutter-apk
copy app-release.apk zhiyuxunzhen-v1.0.2.apk
certutil -hashfile zhiyuxunzhen-v1.0.2.apk SHA256
```

把 SHA256 那串 64 位十六进制**记下来**，可贴到 Release 说明里供校验。

---

## 5. 打 tag 并推送

```cmd
cd /d E:\zhiyu
git tag -a v1.0.2 -m "v1.0.2 多模态链路修复"
git push origin v1.0.2
```

> `deploy.yml` 只监听 `push: branches [main]`，**push tag 不会触发部署** —— 部署在第 2 步已经完成，这里只是给 Release 锚一个版本点。

---

## 6. 创建 GitHub Release

```cmd
gh release create v1.0.2 "E:\zhiyu\mobile\build\app\outputs\flutter-apk\zhiyuxunzhen-v1.0.2.apk" --title "v1.0.2 多模态链路修复" --notes-file "E:\zhiyu\docs\release\v1.0.2-release-notes.md"
```

成功后会打印 Release 页面 URL。想先草稿再发布，加 `--draft`；想发预发布版，加 `--prerelease`。

---

## 7. 验证

```cmd
gh release view v1.0.2
```

浏览器打开：`https://github.com/qianlangzi/zhiyuxunzhen/releases/tag/v1.0.2`
确认三处：① 标题正确 ② 说明正文渲染正常 ③ Assets 里有 `zhiyuxunzhen-v1.0.2.apk` 且大小正常。

**手机端实测（新包才生效）**：

| 场景 | 预期 |
|------|------|
| 学生端 → AI 学伴 → 右滑/点历史 | **抽屉能打开**并列出历史会话（修复前必崩） |
| 问诊室 → **只选图不打字** → 点发送 | 图片正常发出，返回真实读图内容（修复前毫无反应） |
| 问诊室 → 带文字 + 图片一起发 | 图文都发出去（修复前只发文字、图卡住） |
| 备课 → 上传图片课件 → 解析 | 图片被 VLM 识别（修复前恒为空 / 误报「VLM 未配置」） |

> 本包与历史包**同用 debug 签名**、同 applicationId，可直接覆盖安装，无需先卸载。

---

## 8. 常见报错速查

| 报错 | 原因 | 处理 |
|------|------|------|
| `Unable to delete file / 另一个程序正在使用此文件` | Gradle 守护进程占用 | `cd mobile\android && gradlew.bat --stop` 后重试；仍失败则重开终端 |
| `Could not resolve org.*` / 依赖下载超时 | 网络 / 镜像 | 确认 Gradle 走国内镜像；重试构建 |
| `Execution failed for task ':app:processReleaseResources'` | 资源缓存脏 | `flutter clean` 后重建 |
| `gh: Not logged into any GitHub hosts` | gh 未登录 | 回到第 2 步 `gh auth login` |
| `gh release create` 报 tag 已存在 | tag 已 push | 正常，gh 会直接复用该 tag 建 Release |
| 要覆盖已上传的 APK | 重复发版 | `gh release upload v1.0.2 <新apk路径> --clobber` |
| APK 装完连不上后端 | 漏了 `--dart-define` | 重新构建，务必带 `--dart-define=API_BASE_URL=http://8.160.161.158` |

---

## 附：下次发版的版本号位置

| 文件 | 字段 | 说明 |
|------|------|------|
| `mobile/pubspec.yaml` | `version: 1.0.2+3` | `1.0.2` = versionName，`3` = versionCode，**每次发版必须递增** |

改完 `pubspec.yaml` 后，`flutter build apk --release` 会自动同步到 `AndroidManifest`，无需手改 `build.gradle.kts`。
另需在 `docs/release/` 下新建对应版本的说明文件。
