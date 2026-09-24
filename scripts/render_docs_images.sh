#!/bin/bash
#
# 渲染 README 配图。
#
# 把整个 app 的源码和 scripts/docs-images/main.swift 一起编译成一个
# 命令行工具，用 ImageRenderer 把真实的 SwiftUI 视图离屏画成 PNG。不启动 app、
# 不截屏、不发鼠标事件、不需要辅助功能权限，同一份源码出来的图永远一样。
#
# 用法：
#   ./scripts/render_docs_images.sh [输出目录]
# 输出目录默认 docs/images。
#
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT=$(pwd)
OUT_DIR="${1:-$ROOT/docs/images}"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

info() { printf '\033[0;34m%s\033[0m\n' "$1"; }
fail() { printf '\033[0;31m%s\033[0m\n' "$1" >&2; exit 1; }

# 1. 需要一个构建好的 Debug app：渲染器要放进它的 bundle 里跑，
#    这样 Bundle.main 才能解析到 Assets.xcassets 和 7 个 .lproj
#    按修改时间取最新的一个，不能按名字排序：build/ 下会堆着多个版本号目录，
#    字母序最大的未必是最近构建的。用旧产物渲染不会报错，只会悄悄出一张
#    旧文案、旧资源的图——这种错最难发现
APP=$(ls -dt "$ROOT"/build/Usage4Claude-Debug-*/Usage4Claude.app 2>/dev/null | head -1 || true)

#    源码比产物新也要重建，否则同样会拿到过期的 .lproj 和 Assets
if [ -n "$APP" ] && [ -n "$(find "$ROOT/Usage4Claude" -newer "$APP/Contents/MacOS/Usage4Claude" -print -quit 2>/dev/null)" ]; then
    info "源码比构建产物新，重新构建…"
    APP=""
fi

if [ -z "$APP" ]; then
    ./scripts/build.sh --config Debug >/dev/null
    APP=$(ls -dt "$ROOT"/build/Usage4Claude-Debug-*/Usage4Claude.app 2>/dev/null | head -1 || true)
    [ -n "$APP" ] || fail "构建没有产出 app"
fi
info "app bundle: ${APP#$ROOT/}"

# 2. Sparkle。app bundle 里嵌的那份被 Xcode 剥掉了 Headers/Modules，用不了，
#    要的是 SPM 拉下来的 xcframework
SPARKLE=$(find ~/Library/Developer/Xcode/DerivedData -maxdepth 10 \
    -path "*Sparkle.xcframework/macos-arm64_x86_64" -type d 2>/dev/null | head -1)
[ -n "$SPARKLE" ] || fail "找不到 Sparkle.xcframework，先在 Xcode 里构建一次让 SPM 拉取依赖"

# 3. app 的入口文件带 @main，会和渲染器自己的顶层代码冲突。
#    复制一份去掉 @main，其余源码一个字不动
sed '/^@main$/d' "$ROOT/Usage4Claude/App/ClaudeUsageMonitorApp.swift" \
    > "$WORK/ClaudeUsageMonitorApp.nomain.swift"

find "$ROOT/Usage4Claude" -name '*.swift' ! -name 'ClaudeUsageMonitorApp.swift' \
    > "$WORK/sources.txt"
echo "$WORK/ClaudeUsageMonitorApp.nomain.swift" >> "$WORK/sources.txt"
info "编译 $(wc -l < "$WORK/sources.txt" | tr -d ' ') 个源文件…"

swiftc -DDEBUG -Onone \
    -F "$SPARKLE" \
    -Xlinker -rpath -Xlinker "@executable_path/../Frameworks" \
    -target arm64-apple-macos14.0 \
    -o "$WORK/render" \
    "$ROOT/scripts/docs-images/main.swift" \
    @"$WORK/sources.txt"

# 4. 放进 bundle 再跑，Bundle.main 才是 app
cp "$WORK/render" "$APP/Contents/MacOS/DocsImageRenderer"
trap 'rm -rf "$WORK"; rm -f "$APP/Contents/MacOS/DocsImageRenderer"' EXIT

mkdir -p "$OUT_DIR"
# 明暗跑两遍。-AppleInterfaceStyle 走 NSArgumentDomain，优先级最高且不写盘，
# 所以渲染结果和这台机器当前的系统外观无关
"$APP/Contents/MacOS/DocsImageRenderer" "$OUT_DIR" -AppleInterfaceStyle Light
"$APP/Contents/MacOS/DocsImageRenderer" "$OUT_DIR" -AppleInterfaceStyle Dark

info "输出目录：${OUT_DIR#$ROOT/}"
