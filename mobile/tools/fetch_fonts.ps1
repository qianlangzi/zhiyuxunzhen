# 下载思源宋体（Noto Serif SC）可变字体，用于还原与原型一致的标题字体。
# 当前项目通过 fontFamilyFallback 回退到系统宋体（视觉近似），本脚本可一键替换为真实字体。
#
# 用法（PowerShell，项目根目录）:
#   .\tools\fetch_fonts.ps1
#
# 下载成功后，请在 pubspec.yaml 的 fonts: 段中加入以下内容（保留已有的 JetBrainsMono）:
#   - family: NotoSerifSC
#     fonts:
#       - asset: assets/fonts/NotoSerifSC-Variable.ttf
# 然后运行: flutter pub get

$ErrorActionPreference = 'Stop'

$out = Join-Path $PSScriptRoot '..\assets\fonts\NotoSerifSC-Variable.ttf'

# 依次尝试国内可访问的 GitHub 代理 / 镜像
$urls = @(
  'https://ghproxy.com/https://raw.githubusercontent.com/google/fonts/main/ofl/notoserifsc/NotoSerifSC%5Bwght%5D.ttf',
  'https://mirror.ghproxy.com/https://raw.githubusercontent.com/google/fonts/main/ofl/notoserifsc/NotoSerifSC%5Bwght%5D.ttf',
  'https://raw.gitmirror.com/google/fonts/main/ofl/notoserifsc/NotoSerifSC%5Bwght%5D.ttf'
)

foreach ($u in $urls) {
  Write-Host "尝试下载: $u"
  try {
    Invoke-WebRequest -Uri $u -OutFile $out -TimeoutSec 200
    if ((Get-Item $out).Length -gt 100000) {
      Write-Host "下载成功 -> $out" -ForegroundColor Green
      Write-Host "请在 pubspec.yaml 的 fonts: 下加入:" -ForegroundColor Yellow
      Write-Host "  - family: NotoSerifSC`n    fonts:`n      - asset: assets/fonts/NotoSerifSC-Variable.ttf"
      Write-Host "然后运行: flutter pub get" -ForegroundColor Yellow
      exit 0
    }
    else {
      Write-Host "  文件过小，疑似失败，删除后继续尝试其他源。"
      Remove-Item $out -ErrorAction SilentlyContinue
    }
  }
  catch {
    Write-Host "  失败: $_"
  }
}

Write-Host "所有源均失败。请手动从以下地址下载 NotoSerifSC[wght].ttf 并重命名为 NotoSerifSC-Variable.ttf 放入 assets/fonts/:" -ForegroundColor Red
Write-Host "https://github.com/google/fonts/tree/main/ofl/notoserifsc" -ForegroundColor Cyan
