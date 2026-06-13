#!/bin/zsh
# 一键发布到 itch.io：打包网页版 → 修复 Retina 屏缩放 bug → 上传
# 用法：BUTLER_API_KEY=你的钥匙 ./publish.sh
set -e

GODOT="/Users/leozhang/Downloads/Godot.app/Contents/MacOS/Godot"
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$PROJECT_DIR/build/web"
TARGET="leo8654/red-horizon:html5"

echo "==> 1/2 打包网页版..."
"$GODOT" --headless --path "$PROJECT_DIR" --export-release "Web" build/web/index.html

echo "==> 2/2 上传到 itch.io ($TARGET)..."
"$HOME/.local/bin/butler" push "$BUILD_DIR" "$TARGET"
echo "✅ 完成！等服务器处理一两分钟后，强制刷新游戏页面查看。"
