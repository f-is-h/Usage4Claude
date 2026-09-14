#!/bin/bash

# Usage4Claude - Release Notes Generator
# 从模板生成 GitHub Release Notes。
# 若提供 docs/RELEASE_NOTES.md 路径，则把当前版本段落填入模板的 {{RELEASE_NOTES}} 占位，
# 作为 GitHub Release 正文（与 Sparkle 弹窗同源，见 update_appcast.py）。

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================
# Helper Functions
# ============================================

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ Error: $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# ============================================
# Get previous version from git tags
# ============================================
get_previous_version() {
    local current_version="$1"  # Current version to exclude

    # Get all tags sorted by version
    local all_tags=$(git tag -l 'v*' | sort -V)

    if [ -z "$all_tags" ]; then
        # No previous tags
        echo "0.0.0"
        return
    fi

    # Filter out test tags first
    local release_tags=$(echo "$all_tags" | grep -v 'test-')

    # Get all tags before current version (handling the case where current tag doesn't exist yet)
    # This ensures we get the latest tag that is less than current version
    local previous_tags=""
    while IFS= read -r tag; do
        local tag_version="${tag#v}"
        # Skip if this is the current version or later
        if [[ "$tag_version" == "$current_version" ]]; then
            break
        fi
        previous_tags="$tag"
    done <<< "$(echo "$release_tags" | sort -V)"

    if [ -z "$previous_tags" ]; then
        echo "0.0.0"
    else
        # Remove 'v' prefix
        echo "${previous_tags#v}"
    fi
}

# ============================================
# Extract the release-notes section for a version
# 提取 "## [X.Y.Z]" 到下一个 "## [" 之间的内容，并去掉首尾空行。
# 用 index() 做字面匹配，避免版本号里的 "." 被当作正则。
# ============================================
extract_release_notes_section() {
    local notes_path="$1"
    local version="$2"

    awk -v ver="$version" '
        index($0, "## [" ver "]") == 1 { capture = 1; next }
        capture && /^## \[/ { exit }
        capture { lines[n++] = $0 }
        END {
            start = 0
            while (start < n && lines[start] ~ /^[[:space:]]*$/) start++
            end = n - 1
            while (end >= 0 && lines[end] ~ /^[[:space:]]*$/) end--
            for (i = start; i <= end; i++) print lines[i]
        }
    ' "$notes_path"
}

# ============================================
# Generate release notes
# ============================================
generate_notes() {
    local template_path="$1"
    local version="$2"
    local output_path="$3"
    local notes_path="$4"

    # Validate inputs
    if [ ! -f "$template_path" ]; then
        print_error "Template file not found: $template_path"
        exit 1
    fi

    if [ -z "$version" ]; then
        print_error "Version not provided"
        exit 1
    fi

    # Get previous version
    local previous_version=$(get_previous_version "$version")

    print_info "Current version: $version"
    print_info "Previous version: $previous_version"

    # 提取 RELEASE_NOTES 当前版本段落作为 Release 正文
    local release_notes=""
    if [ -n "$notes_path" ] && [ -f "$notes_path" ]; then
        release_notes=$(extract_release_notes_section "$notes_path" "$version")
        if [ -n "$release_notes" ]; then
            print_info "Release notes body filled from RELEASE_NOTES section"
        else
            print_info "No RELEASE_NOTES section for $version; leaving body empty"
        fi
    fi

    # Read template
    local template_content=$(cat "$template_path")

    # Replace variables
    local notes_content="${template_content//\{\{VERSION\}\}/$version}"
    notes_content="${notes_content//\{\{PREVIOUS_VERSION\}\}/$previous_version}"
    notes_content="${notes_content//\{\{RELEASE_NOTES\}\}/$release_notes}"

    # Write to output file
    echo "$notes_content" > "$output_path"

    print_success "Release notes generated: $output_path"
}

# ============================================
# Main Script
# ============================================

show_usage() {
    echo "Usage: $0 <template_path> <version> <output_path> [notes_path]"
    echo ""
    echo "Arguments:"
    echo "  template_path   Path to RELEASE_TEMPLATE.md"
    echo "  version         Current version (e.g., 1.1.3)"
    echo "  output_path     Output file path for generated notes"
    echo "  notes_path      (optional) docs/RELEASE_NOTES.md used to fill {{RELEASE_NOTES}}"
    echo ""
    echo "Example:"
    echo "  $0 .github/RELEASE_TEMPLATE.md 1.1.3 release_notes.md docs/RELEASE_NOTES.md"
}

# Check arguments
if [ $# -lt 3 ]; then
    show_usage
    exit 1
fi

generate_notes "$1" "$2" "$3" "$4"
