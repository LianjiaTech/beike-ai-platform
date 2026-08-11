# 贝壳 CLI 安装脚本（Windows / PowerShell 5.1+）
# 用法：
#   powershell -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/LianjiaTech/beike-ai-platform/main/cli/releases/install.ps1 | iex"
# 选项：
#   -NoForce   已有安装时不覆盖（默认会覆盖）

param([switch]$NoForce)

$ErrorActionPreference = 'Stop'
$overwrite = -not $NoForce

$ManifestUrl = 'https://raw.githubusercontent.com/LianjiaTech/beike-ai-platform/main/cli/releases/manifest.json'
$InstallDir = Join-Path $env:LOCALAPPDATA 'beike'
$ExePath = Join-Path $InstallDir 'beike.exe'

Write-Host '==> 获取版本信息...'
$manifest = Invoke-RestMethod -Uri $ManifestUrl
$version = $manifest.latest
if (-not $version) {
    throw '无法解析版本号'
}
Write-Host "==> 最新版本: $version"

$entry = $manifest.releases |
    Where-Object { $_.version -eq $version } |
    ForEach-Object { $_.binaries } |
    Where-Object { $_.os -eq 'windows' -and $_.arch -eq 'amd64' } |
    Select-Object -First 1

if (-not $entry) {
    throw "当前版本 ($version) 未提供 Windows x64 二进制，请稍后再试"
}

if (Test-Path $ExePath) {
    $existing = & $ExePath --version 2>$null | Select-Object -First 1
    if ($existing -match [regex]::Escape($version)) {
        Write-Host "✓ beike CLI 已是最新版本 ($existing)，跳过"
        exit 0
    }
    if (-not $overwrite) {
        Write-Host "beike 已安装于 $ExePath（如需更新，请去掉 -NoForce）"
        exit 0
    }
    Write-Host "==> 升级 beike CLI $existing → $version..."
}

$tmp = Join-Path $env:TEMP ('beike-install-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmp | Out-Null

try {
    $archive = Join-Path $tmp 'beike.tar.gz'
    Write-Host '==> 下载中...'
    Invoke-WebRequest -Uri $entry.url -OutFile $archive -UseBasicParsing

    if ((Get-Item $archive).Length -lt 1024) {
        throw '下载文件过小，可能已损坏'
    }

    if ($entry.sha256) {
        Write-Host '==> 校验完整性...'
        $actual = (Get-FileHash -Algorithm SHA256 -Path $archive).Hash.ToLower()
        if ($actual -ne $entry.sha256.ToLower()) {
            throw "校验失败`n期望: $($entry.sha256)`n实际: $actual"
        }
        Write-Host '==> 校验通过'
    }

    Write-Host '==> 解压中...'
    $extractDir = Join-Path $tmp 'extract'
    New-Item -ItemType Directory -Path $extractDir | Out-Null
    tar -xzf $archive -C $extractDir
    if ($LASTEXITCODE -ne 0) {
        throw '解压失败（需要 Windows 10 1803+ 自带的 tar）'
    }

    $exe = Get-ChildItem -Path $extractDir -Filter 'beike.exe' -Recurse | Select-Object -First 1
    if (-not $exe) {
        throw '压缩包中未找到 beike.exe'
    }

    Write-Host '==> 安装中...'
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
    Copy-Item $exe.FullName $ExePath -Force

    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $alreadyInPath = $userPath -split ';' |
        Where-Object { $_ -and $_.TrimEnd('\') -eq $InstallDir }
    if (-not $alreadyInPath) {
        $newPath = ($userPath.TrimEnd(';') + ';' + $InstallDir)
        [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
        Write-Host "✓ 已加入用户 PATH: $InstallDir"
    }

    Write-Host '==> 验证中...'
    $ver = & $ExePath --version
    Write-Host ''
    Write-Host "✓ beike CLI $ver 已安装到 $ExePath"
    Write-Host ''
    Write-Host '请重新打开终端，然后运行 beike login 获取并保存 API Key'
}
finally {
    Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
}
