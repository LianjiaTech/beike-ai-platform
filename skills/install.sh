#!/usr/bin/env bash
# 贝壳 Skills 安装脚本（macOS / Linux）
# 用法：
#   curl -fsSL https://raw.githubusercontent.com/LianjiaTech/beike-ai-platform/master/skills/install.sh | bash
#   curl -fsSL ... | bash -s -- beike-buy beike-rent（安装指定 skills）

if [ -z "${BASH_VERSION:-}" ]; then
    exec bash "$0" "$@"
fi
set -uo pipefail

SKILLS_DIR_EXPLICIT="${BEIKE_SKILLS_DIR:-}"
BEIKE_SKILLS_DIR=""
MANIFEST_URL="${BEIKE_MANIFEST_URL:-https://raw.githubusercontent.com/LianjiaTech/beike-ai-platform/master/skills/manifest.json}"
CLI_INSTALL_URL="${BEIKE_CLI_INSTALL_URL:-https://raw.githubusercontent.com/LianjiaTech/beike-ai-platform/master/cli/releases/install.sh}"
CLI_INSTALL_PS1_URL="${BEIKE_CLI_INSTALL_PS1_URL:-https://raw.githubusercontent.com/LianjiaTech/beike-ai-platform/master/cli/releases/install.ps1}"
SKIP_CLI=0

usage() {
    cat <<EOF >&2
贝壳 Skills 安装脚本

用法:
  curl -fsSL https://raw.githubusercontent.com/LianjiaTech/beike-ai-platform/master/skills/install.sh | bash
  curl -fsSL ... | bash -s -- beike-buy beike-rent

选项:
  <skill-name>  指定要安装的 skill（支持多个），默认安装全部
  --skills-dir <目录>
                安装到指定目录；优先级高于自动识别
  --no-cli      只安装 Skills，不安装其依赖的 beike CLI
  -h, --help    显示帮助
EOF
}

requested_skills=()
while [[ $# -gt 0 ]]; do
    case "$1" in
    -h | --help) usage; exit 0 ;;
    --skills-dir)
        if [[ $# -lt 2 || -z "$2" ]]; then
            echo "Error: --skills-dir 需要目录参数" >&2
            usage
            exit 1
        fi
        SKILLS_DIR_EXPLICIT="$2"
        shift 2
        ;;
    --no-cli) SKIP_CLI=1; shift ;;
    -*) echo "Error: 未知参数 $1" >&2; usage; exit 1 ;;
    *) requested_skills+=("$1"); shift ;;
    esac
done

detect_skills_dir() {
    # 优先级：显式参数 > 环境变量（精确识别当前 agent）> 中性默认值
    # 不做目录存在性探测，避免多个 agent 共存时互相干扰
    if [[ -n "$SKILLS_DIR_EXPLICIT" ]]; then
        printf '%s\n' "$SKILLS_DIR_EXPLICIT"
    elif [[ -n "${WORKBUDDY_HOME:-}" ]]; then
        printf '%s/skills\n' "${WORKBUDDY_HOME%/}"
    elif [[ -n "${HERMES_HOME:-}" ]]; then
        printf '%s/skills\n' "${HERMES_HOME%/}"
    elif [[ -n "${OPENCLAW_HOME:-}" ]]; then
        printf '%s/skills\n' "${OPENCLAW_HOME%/}"
    elif [[ -n "${CODEX_THREAD_ID:-}" ]]; then
        printf '%s/.codex/skills\n' "$HOME"
    elif [[ -n "${CLAUDE_CODE:-}${CLAUDECODE:-}" ]]; then
        printf '%s/.claude/skills\n' "$HOME"
    else
        printf '%s/.agents/skills\n' "$HOME"
    fi
}

BEIKE_SKILLS_DIR="$(detect_skills_dir)"

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

is_windows() {
    case "$(uname -s)" in
    *MINGW* | *MSYS* | *CYGWIN*) return 0 ;;
    *) return 1 ;;
    esac
}

download() {
    local url="$1" output="$2"
    local retries=3 n=0
    while [[ $n -lt $retries ]]; do
        [[ $n -gt 0 ]] && sleep 2
        if command -v curl >/dev/null 2>&1; then
            curl -fsSL --retry 2 --connect-timeout 30 --max-time 300 \
                -H "User-Agent: beike-skills-installer/curl-bash" \
                "$url" -o "$output" && return 0
        elif command -v wget >/dev/null 2>&1; then
            wget -q --tries=2 --connect-timeout=30 --read-timeout=300 \
                --user-agent="beike-skills-installer/curl-bash" \
                "$url" -O "$output" && return 0
        else
            echo "Error: 需要 curl 或 wget" >&2; exit 1
        fi
        rm -f "$output" 2>/dev/null || true
        n=$((n + 1))
    done
    return 1
}

TMP_DIR=""
cleanup() {
    [[ -n "$TMP_DIR" && -d "$TMP_DIR" ]] && rm -rf "$TMP_DIR" 2>/dev/null || true
}

install_cli() {
    if [[ "$SKIP_CLI" -eq 1 ]]; then
        echo "ℹ 已跳过 beike CLI 安装（--no-cli）"
        return
    fi

    local cli_manifest_url="${CLI_INSTALL_URL%install.sh}manifest.json"
    local remote_version
    remote_version=$(curl -fsSL "$cli_manifest_url" 2>/dev/null | sed -n 's/.*"latest"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')

    if command -v beike >/dev/null 2>&1; then
        local local_version
        local_version=$(beike --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
        if [[ -n "$remote_version" && "$local_version" == "$remote_version" ]]; then
            echo "✓ beike CLI 已是最新版本 ($local_version)，跳过"
            return
        fi
        echo "==> 升级 beike CLI $local_version → $remote_version..."
    else
        echo "==> 未检测到 beike CLI，正在安装必要依赖..."
    fi

    local cli_installer ps1_path win_beike

    if is_windows; then
        cli_installer="$TMP_DIR/install-beike-cli.ps1"
        if ! download "$CLI_INSTALL_PS1_URL" "$cli_installer"; then
            fatal_error "无法下载 beike CLI 安装脚本" "URL: $CLI_INSTALL_PS1_URL"
        fi
        ps1_path="$cli_installer"
        command -v cygpath >/dev/null 2>&1 && ps1_path="$(cygpath -w "$cli_installer")"
        if ! BEIKE_SKIP_LOGIN_HINT=1 powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$ps1_path"; then
            fatal_error "beike CLI 安装失败"
        fi
        if command -v cygpath >/dev/null 2>&1; then
            win_beike="$(cygpath -u "${LOCALAPPDATA:-$HOME/AppData/Local}/beike/beike.exe")"
        else
            win_beike="${LOCALAPPDATA:-$HOME/AppData/Local}/beike/beike.exe"
        fi
        if [[ ! -f "$win_beike" ]]; then
            fatal_error "beike CLI 安装完成，但未找到 $win_beike"
        fi
        echo "✓ beike CLI 已安装（请重新打开终端后执行 beike --version）"
        return
    fi

    cli_installer="$TMP_DIR/install-beike-cli.sh"
    if ! download "$CLI_INSTALL_URL" "$cli_installer"; then
        fatal_error "无法下载 beike CLI 安装脚本" "URL: $CLI_INSTALL_URL"
    fi
    if ! BEIKE_SKIP_LOGIN_HINT=1 bash "$cli_installer"; then
        fatal_error "beike CLI 安装失败"
    fi
    if ! command -v beike >/dev/null 2>&1; then
        fatal_error "beike CLI 安装完成，但当前 PATH 中未找到 beike" "请重新打开终端后执行 beike --version"
    fi
}

main() {
    TMP_DIR="$(mktemp -d -t beike-skills-install.XXXXXX)"
    trap cleanup EXIT INT TERM

    require_cmd unzip
    require_cmd python3

    echo "==> 获取 Skill 清单..."
    local manifest_file="$TMP_DIR/manifest.json"
    if ! download "$MANIFEST_URL" "$manifest_file"; then
        fatal_error "无法下载 manifest" "URL: $MANIFEST_URL"
    fi

    # 如果未指定 skill，则安装全部
    if [[ ${#requested_skills[@]} -eq 0 ]]; then
        echo "==> 未指定 skill，默认安装全部业务 skill（beike-assistant 为聚合版，需单独安装）"
        requested_skills=($(python3 -c "
import json, sys
try:
    with open('$manifest_file') as f:
        m = json.load(f)
        # 聚合版 beike-assistant 已包含全部业务 skill，默认安装时排除，避免重复加载冲突
        print(' '.join([s['name'] for s in m.get('skills', []) if s['name'] != 'beike-assistant']))
except Exception as e:
    print('', file=sys.stderr)
    sys.exit(1)
" 2>/dev/null)) || fatal_error "无法解析 manifest"

        if [[ ${#requested_skills[@]} -eq 0 ]]; then
            fatal_error "manifest 中没有 skill 或格式错误"
        fi
    fi

    # 防冲突：beike-assistant 只能单独安装，不能与其他业务 skill 同时安装
    if [[ " ${requested_skills[*]} " == *" beike-assistant "* ]] && [[ ${#requested_skills[@]} -gt 1 ]]; then
        fatal_error "beike-assistant 是聚合版（已包含全部业务 skill），请单独安装：install.sh | bash -s -- beike-assistant"
    fi

    echo "==> 计划安装: ${requested_skills[*]}"
    echo "==> Skill 安装目录: $BEIKE_SKILLS_DIR"
    echo ""

    mkdir -p "$BEIKE_SKILLS_DIR"

    # 对每个 skill 进行安装
    for skill_name in "${requested_skills[@]}"; do
        if [[ ! "$skill_name" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
            fatal_error "Skill 名称不合法: $skill_name"
        fi
        echo "==> 安装 $skill_name..."

        # 从 manifest 中查找该 skill 的信息
        local url version checksum
        url=$(python3 -c "
import json
with open('$manifest_file') as f:
    for s in json.load(f).get('skills', []):
        if s.get('name') == '$skill_name':
            print(s.get('url', ''))
            break
" 2>/dev/null) || url=""

        [[ -z "$url" ]] && fatal_error "未找到 Skill: $skill_name"

        version=$(python3 -c "
import json
with open('$manifest_file') as f:
    for s in json.load(f).get('skills', []):
        if s.get('name') == '$skill_name':
            print(s.get('version', 'unknown'))
            break
" 2>/dev/null) || version="unknown"

        checksum=$(python3 -c "
import json
with open('$manifest_file') as f:
    for s in json.load(f).get('skills', []):
        if s.get('name') == '$skill_name':
            print(s.get('sha256', ''))
            break
" 2>/dev/null) || checksum=""

        echo "  版本: $version"

        # 检查本地是否已安装（同版本则跳过）
        local skill_dir="$BEIKE_SKILLS_DIR/$skill_name"
        if [[ -f "$skill_dir/manifest.json" ]]; then
            local local_version
            local_version=$(python3 -c "
import json
with open('$skill_dir/manifest.json') as f:
    print(json.load(f).get('version', 'unknown'))
" 2>/dev/null) || local_version="unknown"

            if [[ "$local_version" == "$version" ]]; then
                echo "  ℹ 已是最新版本，跳过"
                continue
            else
                echo "  ℹ 本地版本 $local_version，准备更新"
            fi
        fi

        local archive_file="$TMP_DIR/$skill_name.zip"
        echo "  下载中..."
        if ! download "$url" "$archive_file"; then
            fatal_error "下载 $skill_name 失败" "URL: $url"
        fi

        local file_size
        file_size=$(wc -c <"$archive_file" 2>/dev/null || echo "0")
        [[ "$file_size" -lt 1024 ]] && fatal_error "下载文件过小，可能已损坏"

        # 校验 sha256；发布清单不允许省略完整性校验。
        if [[ ! "$checksum" =~ ^[0-9a-f]{64}$ ]]; then
            fatal_error "$skill_name 的 manifest 缺少有效 sha256"
        fi
        echo "  校验完整性..."
        local actual=""
        if command -v shasum >/dev/null 2>&1; then
            actual=$(shasum -a 256 "$archive_file" | cut -d' ' -f1)
        elif command -v sha256sum >/dev/null 2>&1; then
            actual=$(sha256sum "$archive_file" | cut -d' ' -f1)
        else
            fatal_error "系统缺少 SHA-256 校验命令"
        fi
        if [[ "$actual" != "$checksum" ]]; then
            fatal_error "校验失败"
        fi

        echo "  解压中..."
        mkdir -p "$skill_dir"
        unzip -oq "$archive_file" -d "$skill_dir" || fatal_error "解压失败"

        # 检查必需文件
        if [[ ! -f "$skill_dir/SKILL.md" ]]; then
            fatal_error "压缩包格式错误（缺少 SKILL.md）"
        fi

        echo "  ✓ 安装成功"
        echo ""
    done

    install_cli
    echo ""

    echo "=== 安装完成 ==="
    echo "✓ 已安装以下 Skills:"
    for skill_name in "${requested_skills[@]}"; do
        skill_dir="$BEIKE_SKILLS_DIR/$skill_name"
        if [[ -f "$skill_dir/manifest.json" ]]; then
            version=$(python3 -c "import json; print(json.load(open('$skill_dir/manifest.json')).get('version', 'unknown'))" 2>/dev/null || echo "unknown")
            echo "  • $skill_name@$version"
        fi
    done
    echo ""
    echo "位置: $BEIKE_SKILLS_DIR"
    echo ""
    if [[ -n "${BEIKE_MCP_API_KEY:-}" || -s "$HOME/.beike/BEIKE_MCP_API_KEY" ]]; then
        echo "✓ 已检测到 API Key，可以开始使用"
    else
        echo "下一步：打开以下链接登录获取 API Key（请直接使用此链接，无需运行其他命令）："
        echo "  https://building.ke.com/?action=get-key&source=beike_skill"
        if command -v beike >/dev/null 2>&1 || is_windows; then
            echo ""
            echo "登录后把页面上的身份凭证复制给 AI 助手即可完成保存；或自行执行："
            echo "  beike auth <YOUR_API_KEY> --save"
        fi
    fi
}

main "$@"
