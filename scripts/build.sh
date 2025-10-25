#!/bin/bash

# Usage4Claude 构建打包脚本
# 功能：编译 Xcode 项目，导出 .app，创建 DMG 安装包
# 用法：./scripts/build.sh [--no-clean] [--config Release|Debug] [--verbose|-v]

set -e  # 遇到错误立即退出
set -o pipefail  # 管道命令中任何一个失败都会导致整个管道失败

# ============================================
# 颜色输出
# ============================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================
# 辅助函数
# ============================================
print_header() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ 错误: $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  警告: $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# ============================================
# 配置变量
# ============================================
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_NAME="Usage4Claude"
SCHEME_NAME="Usage4Claude"
XCODEPROJ="${PROJECT_ROOT}/${PROJECT_NAME}.xcodeproj"
BUILD_DIR="${PROJECT_ROOT}/build"

# 默认参数
BUILD_CONFIG="Release"
SHOULD_CLEAN=true
VERBOSE=false

# ============================================
# 解析命令行参数
# ============================================
while [[ $# -gt 0 ]]; do
    case $1 in
        --no-clean)
            SHOULD_CLEAN=false
            shift
            ;;
        --config)
            BUILD_CONFIG="$2"
            shift 2
            ;;
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --help|-h)
            echo "用法: $0 [选项]"
            echo ""
            echo "选项:"
            echo "  --no-clean          跳过 Xcode clean（默认会执行 clean）"
            echo "  --config <config>   指定构建配置 (Release|Debug)，默认 Release"
            echo "  --verbose, -v       显示详细构建日志（默认只显示摘要）"
            echo "  --help, -h          显示此帮助信息"
            echo ""
            echo "示例:"
            echo "  $0                  # 默认：clean + Release 构建"
            echo "  $0 --no-clean       # 跳过 clean"
            echo "  $0 --config Debug   # 使用 Debug 配置"
            echo "  $0 --verbose        # 显示详细日志"
            exit 0
            ;;
        *)
            print_error "未知参数: $1"
            echo "使用 --help 查看帮助"
            exit 1
            ;;
    esac
done

# ============================================
# 检查依赖
# ============================================
print_header "检查依赖"

# 检查 xcodebuild
if ! command -v xcodebuild &> /dev/null; then
    print_error "未找到 xcodebuild，请安装 Xcode"
    exit 1
fi
print_success "xcodebuild 已安装"

# 检查 create-dmg
if ! command -v create-dmg &> /dev/null; then
    print_error "未找到 create-dmg"
    echo ""
    echo "请执行以下命令安装："
    echo "  brew install create-dmg"
    exit 1
fi
print_success "create-dmg 已安装"

# 检查项目文件
if [ ! -d "$XCODEPROJ" ]; then
    print_error "未找到项目文件: $XCODEPROJ"
    exit 1
fi
print_success "项目文件存在"

# ============================================
# 读取版本号
# ============================================
print_header "读取版本号"

VERSION=$(xcodebuild -project "$XCODEPROJ" -showBuildSettings | grep MARKETING_VERSION | head -1 | awk '{print $3}')

if [ -z "$VERSION" ]; then
    print_error "无法从 Xcode 项目读取版本号"
    exit 1
fi

print_success "版本号: $VERSION"

# 设置输出目录
EXPORT_DIR="${BUILD_DIR}/${PROJECT_NAME}-${BUILD_CONFIG}-${VERSION}"
DMG_NAME="${PROJECT_NAME}-v${VERSION}.dmg"
DMG_PATH="${EXPORT_DIR}/${DMG_NAME}"
LOG_FILE="${EXPORT_DIR}/build.log"
ARCHIVE_PATH="${EXPORT_DIR}/${PROJECT_NAME}.xcarchive"

print_info "输出目录: $EXPORT_DIR"
print_info "DMG 文件名: $DMG_NAME"

if [ "$VERBOSE" = false ]; then
    print_info "详细日志: $LOG_FILE"
fi

# 创建输出目录
mkdir -p "$EXPORT_DIR"

# 清空日志文件（如果使用简洁模式）
if [ "$VERBOSE" = false ]; then
    > "$LOG_FILE"
fi

# ============================================
# 清理
# ============================================
if [ "$SHOULD_CLEAN" = true ]; then
    print_header "清理构建"
    
    if [ "$VERBOSE" = true ]; then
        xcodebuild clean \
            -project "$XCODEPROJ" \
            -scheme "$SCHEME_NAME" \
            -configuration "$BUILD_CONFIG" \
            -destination "generic/platform=macOS,name=Any Mac"
    else
        print_info "正在清理..."
        xcodebuild clean \
            -project "$XCODEPROJ" \
            -scheme "$SCHEME_NAME" \
            -configuration "$BUILD_CONFIG" \
            -destination "generic/platform=macOS,name=Any Mac" \
            >> "$LOG_FILE" 2>&1
    fi
    
    print_success "清理完成"
else
    print_info "跳过清理步骤"
fi

# ============================================
# Archive（编译打包）
# ============================================
print_header "Archive（编译打包）"

# 删除旧的 archive（如果存在）
if [ -d "$ARCHIVE_PATH" ]; then
    print_info "删除旧的 archive"
    rm -rf "$ARCHIVE_PATH"
fi

print_info "开始编译..."
print_info "配置: $BUILD_CONFIG"
print_info "目标: Any Mac (Universal Binary)"

if [ "$VERBOSE" = true ]; then
    # 详细模式：显示所有输出
    xcodebuild archive \
        -project "$XCODEPROJ" \
        -scheme "$SCHEME_NAME" \
        -configuration "$BUILD_CONFIG" \
        -archivePath "$ARCHIVE_PATH" \
        -destination "generic/platform=macOS,name=Any Mac" \
        CODE_SIGN_IDENTITY="Usage4Claude-CodeSigning" \
        CODE_SIGN_STYLE=Manual \
        DEVELOPMENT_TEAM=""
    ARCHIVE_RESULT=$?
else
    # 简洁模式：只显示进度
    print_info "编译中，请稍候...（通常需要 1-2 分钟）"
    xcodebuild archive \
        -project "$XCODEPROJ" \
        -scheme "$SCHEME_NAME" \
        -configuration "$BUILD_CONFIG" \
        -archivePath "$ARCHIVE_PATH" \
        -destination "generic/platform=macOS,name=Any Mac" \
        CODE_SIGN_IDENTITY="Usage4Claude-CodeSigning" \
        CODE_SIGN_STYLE=Manual \
        DEVELOPMENT_TEAM="" \
        >> "$LOG_FILE" 2>&1
    ARCHIVE_RESULT=$?
fi

if [ $ARCHIVE_RESULT -ne 0 ] || [ ! -d "$ARCHIVE_PATH" ]; then
    print_error "Archive 失败"
    if [ "$VERBOSE" = false ]; then
        print_info "显示最后 20 行日志："
        echo ""
        tail -n 20 "$LOG_FILE"
        echo ""
        print_info "完整日志: $LOG_FILE"
    fi
    exit 1
fi

print_success "Archive 完成"

# ============================================
# Export（导出 .app）
# ============================================
print_header "Export（导出 .app）"

# 创建导出配置 plist
EXPORT_OPTIONS_PLIST="${EXPORT_DIR}/ExportOptions.plist"
cat > "$EXPORT_OPTIONS_PLIST" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>mac-application</string>
    <key>signingStyle</key>
    <string>manual</string>
    <key>stripSwiftSymbols</key>
    <true/>
</dict>
</plist>
EOF

print_info "导出到: $EXPORT_DIR"

if [ "$VERBOSE" = true ]; then
    # 详细模式：显示所有输出
    xcodebuild -exportArchive \
        -archivePath "$ARCHIVE_PATH" \
        -exportPath "$EXPORT_DIR" \
        -exportOptionsPlist "$EXPORT_OPTIONS_PLIST"
    EXPORT_RESULT=$?
else
    # 简洁模式：只显示进度
    print_info "导出中..."
    xcodebuild -exportArchive \
        -archivePath "$ARCHIVE_PATH" \
        -exportPath "$EXPORT_DIR" \
        -exportOptionsPlist "$EXPORT_OPTIONS_PLIST" \
        >> "$LOG_FILE" 2>&1
    EXPORT_RESULT=$?
fi

if [ $EXPORT_RESULT -ne 0 ] || [ ! -d "${EXPORT_DIR}/${PROJECT_NAME}.app" ]; then
    print_error "导出 .app 失败"
    if [ "$VERBOSE" = false ]; then
        print_info "显示最后 20 行日志："
        echo ""
        tail -n 20 "$LOG_FILE"
        echo ""
        print_info "完整日志: $LOG_FILE"
    fi
    exit 1
fi

print_success "导出完成: ${EXPORT_DIR}/${PROJECT_NAME}.app"

# ============================================
# 创建 DMG
# ============================================
print_header "创建 DMG 安装包"

# 删除旧的 DMG（如果存在）
if [ -f "$DMG_PATH" ]; then
    print_info "删除旧的 DMG: $DMG_PATH"
    rm -f "$DMG_PATH"
fi

# 检查 DMG 图标文件
DMG_ICON="${PROJECT_ROOT}/docs/images/DmgIcon.icns"
if [ ! -f "$DMG_ICON" ]; then
    print_warning "未找到 DMG 图标文件: $DMG_ICON"
    print_info "将创建不带图标的 DMG"
    VOLICON_OPTION=""
else
    VOLICON_OPTION="--volicon ${DMG_ICON}"
fi

cd "$EXPORT_DIR"

if [ "$VERBOSE" = true ]; then
    # 详细模式：显示所有 create-dmg 输出
    print_info "创建 DMG: $DMG_NAME"
    create-dmg \
      --volname "${PROJECT_NAME}" \
      ${VOLICON_OPTION} \
      --window-pos 200 120 \
      --window-size 600 500 \
      --icon-size 128 \
      --icon "${PROJECT_NAME}.app" 175 190 \
      --hide-extension "${PROJECT_NAME}.app" \
      --app-drop-link 425 190 \
      "$DMG_NAME" \
      "${PROJECT_NAME}.app" 2>&1 | grep -v "Failed running AppleScript" || true
    DMG_RESULT=$?
else
    # 简洁模式：只显示进度信息
    print_info "创建 DMG 中..."
    create-dmg \
      --volname "${PROJECT_NAME}" \
      ${VOLICON_OPTION} \
      --window-pos 200 120 \
      --window-size 600 500 \
      --icon-size 128 \
      --icon "${PROJECT_NAME}.app" 175 190 \
      --hide-extension "${PROJECT_NAME}.app" \
      --app-drop-link 425 190 \
      "$DMG_NAME" \
      "${PROJECT_NAME}.app" \
      >> "$LOG_FILE" 2>&1
    DMG_RESULT=$?
fi

set -e

# 检查 DMG 是否真的创建成功
if [ ! -f "$DMG_PATH" ]; then
    print_error "创建 DMG 失败"
    if [ "$VERBOSE" = false ]; then
        print_info "显示最后 20 行日志："
        echo ""
        tail -n 20 "$LOG_FILE"
        echo ""
        print_info "完整日志: $LOG_FILE"
    fi
    exit 1
fi

if [ $DMG_RESULT -ne 0 ]; then
    if [ "$VERBOSE" = true ]; then
        print_warning "DMG 创建过程中有警告，但 DMG 文件已成功创建"
    fi
fi

print_success "DMG 创建完成: $DMG_PATH"

# ============================================
# 清理临时文件
# ============================================
print_header "清理临时文件"

rm -f "$EXPORT_OPTIONS_PLIST"
rm -rf "$ARCHIVE_PATH"

print_success "清理完成"

# ============================================
# 构建摘要
# ============================================
print_header "构建完成 🎉"

echo ""
print_success "版本: $VERSION"
print_success "配置: $BUILD_CONFIG"
print_success "输出目录: $EXPORT_DIR"
echo ""
print_info "构建产物:"
echo "  📦 应用程序: ${EXPORT_DIR}/${PROJECT_NAME}.app"
echo "  💿 DMG 安装包: ${DMG_PATH}"
echo ""

# 获取 DMG 文件大小
DMG_SIZE=$(du -h "$DMG_PATH" | awk '{print $1}')
print_info "DMG 大小: $DMG_SIZE"

echo ""
print_success "全部完成！"
echo ""
