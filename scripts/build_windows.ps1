param([switch]$Clean, [switch]$Upgrade, [switch]$Msix)
$ErrorActionPreference = 'Stop'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootDir = Split-Path -Parent $scriptDir
$appDir = Join-Path $rootDir 'mobile_app'
if (!(Test-Path $appDir)) { Write-Error "未找到目录: $appDir" }
Set-Location $appDir
try { & flutter --version | Out-Null } catch { Write-Error '未检测到 Flutter，请先安装并配置环境'; exit 1 }
& flutter config --enable-windows-desktop
try { & flutter doctor -v | Out-Null } catch {}
if ($Clean) {
  & flutter clean
  $buildWin = Join-Path $appDir 'build\\windows'
  if (Test-Path $buildWin) { Remove-Item -Path $buildWin -Recurse -Force -ErrorAction SilentlyContinue }
}
if ($Upgrade) { & flutter pub upgrade --major-versions }
& flutter pub get
# 尝试关闭正在运行的 exe，避免 LNK1104 无法覆盖
try {
  Get-Process -Name 'mobile_app' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
} catch {}
& flutter build windows --release
if ($LASTEXITCODE -ne 0) { Write-Error '构建失败：flutter build 返回非零退出码'; exit 10 }
$exeDir = Join-Path $appDir 'build\\windows\\x64\\runner\\Release'
if (!(Test-Path $exeDir)) { Write-Error "未找到构建输出目录: $exeDir"; exit 2 }
$exe = Get-ChildItem -Path $exeDir -Filter '*.exe' | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($null -eq $exe) { Write-Error '未找到可执行文件'; exit 3 }
Write-Host "构建成功: $($exe.FullName)" -ForegroundColor Green
Write-Host "输出目录: $exeDir" -ForegroundColor Green
Start-Process explorer.exe $exeDir

# 可选：MSIX 安装包构建
if ($Msix) {
  Write-Host '开始构建 MSIX 安装包...' -ForegroundColor Cyan
  try {
    # 安装 msix 插件（若已安装会忽略）
    & flutter pub add msix | Out-Null
  } catch {}
  try {
    & flutter pub run msix:create
  } catch {
    Write-Warning 'MSIX 构建失败，请在 pubspec.yaml 中配置 msix_config（identity_name、publisher_display_name、logo 等）后重试。'
  }
  $msixDir = Join-Path $appDir 'build'
  $msix = Get-ChildItem -Path $msixDir -Filter '*.msix' -Recurse | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if ($msix) {
    Write-Host "MSIX 构建成功: $($msix.FullName)" -ForegroundColor Green
    Start-Process explorer.exe (Split-Path -Parent $msix.FullName)
  } else {
    Write-Warning '未找到生成的 .msix 文件，请检查 msix 插件输出目录（通常在 build/**/msix 或 build/）。'
  }
}
