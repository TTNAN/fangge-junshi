#!/usr/bin/env bash
#
# fangge-junshi（防割军师）一键安装 / 卸载脚本
#
set -euo pipefail

SCRIPT_VERSION="1.1.0"
REPO="TTNAN/fangge-junshi"
REF="main"
TARGET="claude"
UNINSTALL=0

SKILL_NAME="fangge-junshi"
# 安装进 skill 目录的文件（不含 .github 等仓库维护文件）
SKILL_FILES="SKILL.md README.md README_en.md LICENSE references examples assets"
BACKUP_ROOT="$HOME/.fangge-junshi-backup"
MARKER=".installed-by-fangge-junshi"

usage() {
cat <<'HELP_EOF'
fangge-junshi（防割军师）一键安装 / 卸载脚本

安装（默认装到 Claude Code）:
  curl -fsSL https://raw.githubusercontent.com/TTNAN/fangge-junshi/main/install.sh | bash

常用变体:
  bash -s -- --target agents           # Codex / Cursor / Gemini CLI / Copilot / OpenCode……
                                          # 这 40+ 家都读 ~/.agents/skills，装一份就行
  bash -s -- --target windsurf         # ~/.windsurf/skills
  bash -s -- --target trae             # ~/.trae/skills
  bash -s -- --target qoder            # ~/.qoder/skills
  bash -s -- --target all              # 以上全装
  bash -s -- --ref v1.0.0              # 指定版本安装
  bash -s -- --uninstall               # 卸载（只删本包的 skill，不动你自己的）

已有同名 skill 时:
  - 是本包之前装的：直接覆盖，不备份
  - 是你自己的（比如你手写的 fangge-junshi）：挪到 ~/.fangge-junshi-backup/，不会丢

参数:
  --target <name|all>   装到哪个 Agent（默认 claude）：
                          claude | agents | windsurf | trae | qoder | all
  --ref <branch|tag|commit>  指定版本（默认 main）
  --uninstall               卸载本包的 skill
  -h, --help                显示本帮助

目录映射参考 vercel-labs/skills：绝大多数现代 Agent
（Codex / Cursor / Gemini CLI / Copilot / OpenCode / Cline / Warp / Zed…）
都读 ~/.agents/skills，只有少数几家用自己的目录。
HELP_EOF
}

need_value() { # $1=flag, $2=value
  if [[ -z "${2:-}" || "$2" == -* ]]; then
    echo "错误：$1 后面要跟一个值（用 --help 看用法）" >&2
    exit 1
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --uninstall) UNINSTALL=1; shift ;;
    --target) need_value "$1" "${2:-}"; TARGET="$2"; shift 2 ;;
    --ref)    need_value "$1" "${2:-}"; REF="$2";    shift 2 ;;
    *) echo "未知参数: $1（用 --help 看用法）" >&2; exit 1 ;;
  esac
done

case "$TARGET" in
  claude|agents|windsurf|trae|qoder|all) ;;
  *) echo "错误：--target 必须是 claude / agents / windsurf / trae / qoder / all" >&2; exit 1 ;;
esac

# 目标目录：每行 "标签 目录"
dest_dirs() {
  case "$TARGET" in
    claude)
      echo "claude $HOME/.claude/skills" ;;
    agents)
      echo "agents $HOME/.agents/skills" ;;
    windsurf)
      echo "windsurf $HOME/.windsurf/skills" ;;
    trae)
      echo "trae $HOME/.trae/skills" ;;
    qoder)
      echo "qoder $HOME/.qoder/skills" ;;
    all)
      echo "claude $HOME/.claude/skills"
      echo "agents $HOME/.agents/skills"
      echo "windsurf $HOME/.windsurf/skills"
      echo "trae $HOME/.trae/skills"
      echo "qoder $HOME/.qoder/skills" ;;
  esac
}

# ---- 卸载：只删本包的 skill ----
if [[ "$UNINSTALL" == "1" ]]; then
  while read -r _label dir; do
    if [[ -f "$dir/$SKILL_NAME/$MARKER" ]]; then
      rm -rf "$dir/$SKILL_NAME"
      echo "已删除 $dir/$SKILL_NAME"
    elif [[ -e "$dir/$SKILL_NAME" ]]; then
      echo "跳过 $dir/$SKILL_NAME（不是本包装的，不动）"
    fi
  done < <(dest_dirs)
  echo "卸载完成。"
  exit 0
fi

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

echo "==> 下载 fangge-junshi@$REF ..."
curl -fsSL "https://github.com/${REPO}/archive/${REF}.tar.gz" -o "$WORKDIR/repo.tar.gz"
tar -xzf "$WORKDIR/repo.tar.gz" -C "$WORKDIR"
# 不把解压目录名写死：tag 会去掉开头的 v，分支名带 / 也会变，glob 最稳
SRC="$(echo "$WORKDIR"/*/)"
for f in $SKILL_FILES; do
  if [[ ! -e "$SRC$f" ]]; then
    echo "错误：下载的包里找不到 $f（版本 $REF 可能有问题）" >&2
    exit 1
  fi
done

TS="$(date +%Y%m%d%H%M%S)"

install_one() { # $1=标签 $2=目标目录
  local label="$1" dest="$2"
  mkdir -p "$dest"
  if [[ -e "$dest/$SKILL_NAME" ]]; then
    if [[ -f "$dest/$SKILL_NAME/$MARKER" ]]; then
      # 本包之前装的：直接覆盖，不备份
      rm -rf "$dest/$SKILL_NAME"
    else
      # 用户自己的 skill：挪到备份目录，不能留在 skills 里（会跟新版同时被加载）
      local bak="$BACKUP_ROOT/$TS/$label-$SKILL_NAME"
      mkdir -p "$BACKUP_ROOT/$TS"
      mv "$dest/$SKILL_NAME" "$bak"
      echo "  注意：$dest/$SKILL_NAME 不是本包装的，已备份到 $bak"
    fi
  fi
  mkdir -p "$dest/$SKILL_NAME"
  for f in $SKILL_FILES; do
    cp -r "$SRC$f" "$dest/$SKILL_NAME"/
  done
  echo "$SCRIPT_VERSION" > "$dest/$SKILL_NAME/$MARKER"
  echo "==> 已安装 $SKILL_NAME 到 $dest"
}

while read -r label dir; do
  install_one "$label" "$dir"
done < <(dest_dirs)

echo ""
echo "完成（脚本版本 $SCRIPT_VERSION）。"
echo "重启你的 Agent（或开新会话）后 skill 自动生效。"
echo "查看：ls ~/.claude/skills ~/.agents/skills"
echo "卸载：curl -fsSL https://raw.githubusercontent.com/TTNAN/fangge-junshi/main/install.sh | bash -s -- --uninstall"
