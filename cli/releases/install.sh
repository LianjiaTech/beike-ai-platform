#!/usr/bin/env bash
# 贝壳 CLI 安装脚本（macOS / Linux）
# curl -fsSL https://raw.githubusercontent.com/LianjiaTech/beike-ai-platform/master/cli/releases/install.sh | bash
if [ -z "${BASH_VERSION:-}" ]; then
    exec bash "$0" "$@"
fi
set -uo pipefail

BEIKE_BASE_URL="${BEIKE_RELEASE_URL:-https://github.com/LianjiaTech/beike-ai-platform/releases/download}"
MANIFEST_URL="${BEIKE_MANIFEST_URL:-https://raw.githubusercontent.com/LianjiaTech/beike-ai-platform/master/cli/releases/manifest.json}"
FORCE=1

usage() {
    cat <<EOF >&2
贝壳 CLI 安装脚本

用法:
  curl -fsSL ${BEIKE_BASE_URL}/install | bash
  curl -fsSL ${BEIKE_BASE_URL}/install | bash -s -- [OPTIONS]

选项:
  --no-force  已有安装时不覆盖（默认会覆盖）
  --force     显式覆盖已有安装（默认行为）
  -h, --help  显示帮助
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
    -h | --help) usage; exit 0 ;;
    --no-force) FORCE=0; shift ;;
    --force)    FORCE=1; shift ;;
    *) echo "Error: 未知参数 $1" >&2; usage; exit 1 ;;
    esac
done

require_cmd() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "Error: 需要 $1 但未安装" >&2
        exit 1
    fi
}

fatal_error() {
    echo "" >&2
    echo "错误: $1" >&2
    if [[ $# -gt 1 ]]; then
        shift
        for msg in "$@"; do echo "  - $msg" >&2; done
    fi
    echo "" >&2
    exit 1
}

download() {
    local url="$1" output="$2"
    local retries=3 n=0
    while [[ $n -lt $retries ]]; do
        [[ $n -gt 0 ]] && sleep 2
        if command -v curl >/dev/null 2>&1; then
            curl -fsSL --retry 2 --connect-timeout 30 --max-time 300 \
                -H "User-Agent: beike-cli-installer/curl-bash" \
                "$url" -o "$output" && return 0
        elif command -v wget >/dev/null 2>&1; then
            wget -q --tries=2 --connect-timeout=30 --read-timeout=300 \
                --user-agent="beike-cli-installer/curl-bash" \
                "$url" -O "$output" && return 0
        else
            echo "Error: 需要 curl 或 wget" >&2; exit 1
        fi
        rm -f "$output" 2>/dev/null || true
        n=$((n + 1))
    done
    return 1
}

detect_os_arch() {
    local os arch
    os="$(uname -s | tr '[:upper:]' '[:lower:]')"
    arch="$(uname -m)"
    # Rosetta 检测
    if [[ "$os" == "darwin" && "$arch" == "x86_64" ]]; then
        if sysctl -n hw.optional.arm64 2>/dev/null | grep -q '1'; then
            arch="arm64"
            echo "==> 检测到 Apple Silicon (Rosetta)，使用 arm64 binary" >&2
        fi
    fi
    [[ "$arch" == "aarch64" ]] && arch="arm64"
    [[ "$arch" == "x86_64" ]]  && arch="amd64"
    echo "$os $arch"
}

TMP_DIR=""
cleanup() {
    [[ -n "$TMP_DIR" && -d "$TMP_DIR" ]] && rm -rf "$TMP_DIR" 2>/dev/null || true
}

main() {
    local os_name
    os_name="$(uname -s | tr '[:upper:]' '[:lower:]')"
    if [[ "$os_name" == *"mingw"* || "$os_name" == *"cygwin"* || "$os_name" == *"msys"* ]]; then
        echo "Windows 请使用 PowerShell 安装（本脚本不支持 Git Bash）：" >&2
        echo "  powershell -ExecutionPolicy Bypass -Command \"irm https://raw.githubusercontent.com/LianjiaTech/beike-ai-platform/master/cli/releases/install.ps1 | iex\"" >&2
        exit 1
    fi

    TMP_DIR="$(mktemp -d -t beike-install.XXXXXX)"
    trap cleanup EXIT INT TERM

    local os arch
    read -r os arch < <(detect_os_arch)

    if [[ "$os" != "darwin" && "$os" != "linux" ]]; then
        fatal_error "不支持的系统: $os"
    fi

    echo "==> 平台: $os/$arch"
    echo "==> 获取版本信息..."

    local manifest_file="$TMP_DIR/manifest.json"
    if ! download "$MANIFEST_URL" "$manifest_file"; then
        fatal_error "无法下载 manifest" "URL: $MANIFEST_URL"
    fi

    local manifest_json version download_url checksum
    manifest_json="$(cat "$manifest_file")"
    version=$(printf '%s' "$manifest_json" | sed -n 's/.*"latest"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
    [[ -z "$version" ]] && fatal_error "无法解析版本号"

    echo "==> 最新版本: $version"

    # 从 manifest 中查找匹配的二进制（匹配 os 和 arch）
    local entry
    entry=$(printf '%s' "$manifest_json" | tr -d '\n\r\t ' | sed 's/},{/}\n{/g' \
        | grep -F "\"os\":\"$os\"" | grep -F "\"arch\":\"$arch\"" | head -n1)
    [[ -z "$entry" ]] && fatal_error "暂不支持 $os/$arch"

    download_url=$(printf '%s' "$entry" | sed -n 's/.*"url"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
    checksum=$(printf '%s' "$entry"     | sed -n 's/.*"sha256"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
    [[ -z "$download_url" ]] && fatal_error "manifest 中缺少下载地址"

    echo "==> 下载 beike $version..."
    local archive_file="$TMP_DIR/beike.tar.gz"
    require_cmd tar

    if ! download "$download_url" "$archive_file"; then
        fatal_error "下载失败" "URL: $download_url"
    fi

    local file_size
    file_size=$(wc -c <"$archive_file" 2>/dev/null || echo "0")
    [[ "$file_size" -lt 1024 ]] && fatal_error "下载文件过小 ($file_size bytes)，可能已损坏"

    if [[ -n "$checksum" ]]; then
        echo "==> 校验完整性..."
        local actual=""
        if command -v shasum    >/dev/null 2>&1; then actual=$(shasum -a 256 "$archive_file" | cut -d' ' -f1)
        elif command -v sha256sum >/dev/null 2>&1; then actual=$(sha256sum "$archive_file" | cut -d' ' -f1)
        fi
        if [[ -n "$actual" && "$actual" != "$checksum" ]]; then
            fatal_error "校验失败" "期望: $checksum" "实际: $actual"
        fi
        echo "==> 校验通过"
    fi

    echo "==> 解压..."
    local extract_dir="$TMP_DIR/extract"
    mkdir -p "$extract_dir"
    tar -xzf "$archive_file" -C "$extract_dir" || fatal_error "解压失败"

    [[ ! -f "$extract_dir/beike" ]] && fatal_error "压缩包中未找到 beike binary"
    chmod +x "$extract_dir/beike"

    echo "==> 安装..."
    local install_args=(install)
    [[ "$FORCE" -eq 1 ]] && install_args+=(--force)

    if ! "$extract_dir/beike" "${install_args[@]}"; then
        fatal_error "install 子命令执行失败"
    fi

    echo ""
    echo "=== 安装完成 ==="
    echo "✓ beike CLI $version 已安装"
    echo ""
    echo "运行以下命令开始使用："
    echo "  beike --help"
    echo ""
    echo "下一步：运行 beike login 获取登录链接并打开获取 API Key"
    echo "  beike login"
    echo ""
    echo "获取后保存："
    echo "  beike auth <YOUR_API_KEY> --save"
}

main "$@"
