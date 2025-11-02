#!/bin/bash

# Usage4Claude - Version Verification Script
# This script extracts and verifies version numbers from CHANGELOG.md and Xcode project

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

print_warning() {
    echo -e "${YELLOW}⚠️  Warning: $1${NC}"
}

# ============================================
# Extract version from CHANGELOG.md
# ============================================
extract_version() {
    local changelog_path="$1"
    
    if [ ! -f "$changelog_path" ]; then
        print_error "CHANGELOG.md not found at: $changelog_path"
        exit 1
    fi
    
    # Extract version: ## [1.1.3] - 2025-11-02
    local version=$(grep -m 1 '## \[' "$changelog_path" | sed 's/.*\[\(.*\)\].*/\1/')
    
    if [ -z "$version" ]; then
        print_error "Could not extract version from CHANGELOG.md"
        print_info "Expected format: ## [X.Y.Z] - YYYY-MM-DD"
        exit 1
    fi
    
    # Validate version format (X.Y.Z)
    if ! [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        print_error "Invalid version format: $version"
        print_info "Expected format: X.Y.Z (e.g., 1.1.3)"
        exit 1
    fi
    
    echo "$version"
}

# ============================================
# Extract version from Xcode project
# ============================================
extract_xcode_version() {
    local project_path="$1"
    
    if [ ! -d "$project_path" ]; then
        print_error "Xcode project not found at: $project_path"
        exit 1
    fi
    
    # Use xcodebuild to get MARKETING_VERSION
    local version=$(xcodebuild -project "$project_path" -showBuildSettings 2>/dev/null | \
                    grep MARKETING_VERSION | head -1 | awk '{print $3}')
    
    if [ -z "$version" ]; then
        print_error "Could not extract MARKETING_VERSION from Xcode project"
        exit 1
    fi
    
    echo "$version"
}

# ============================================
# Verify versions match
# ============================================
verify_versions() {
    local changelog_version="$1"
    local xcode_version="$2"
    
    print_info "CHANGELOG version: $changelog_version"
    print_info "Xcode version: $xcode_version"
    
    if [ "$changelog_version" = "$xcode_version" ]; then
        print_success "Version numbers match!"
        return 0
    else
        print_error "Version mismatch!"
        echo ""
        echo "CHANGELOG.md: $changelog_version"
        echo "Xcode project: $xcode_version"
        echo ""
        print_info "Please update the version number in Xcode to match CHANGELOG.md"
        return 1
    fi
}

# ============================================
# Main Script
# ============================================

show_usage() {
    echo "Usage: $0 <command> [arguments]"
    echo ""
    echo "Commands:"
    echo "  extract-changelog <changelog_path>    Extract version from CHANGELOG.md"
    echo "  extract-xcode <project_path>          Extract version from Xcode project"
    echo "  verify <changelog_path> <project_path> Verify versions match"
    echo ""
    echo "Examples:"
    echo "  $0 extract-changelog CHANGELOG.md"
    echo "  $0 extract-xcode Usage4Claude.xcodeproj"
    echo "  $0 verify CHANGELOG.md Usage4Claude.xcodeproj"
}

# Check arguments
if [ $# -eq 0 ]; then
    show_usage
    exit 1
fi

COMMAND="$1"

case "$COMMAND" in
    extract-changelog)
        if [ $# -ne 2 ]; then
            print_error "Missing argument: changelog_path"
            show_usage
            exit 1
        fi
        extract_version "$2"
        ;;
    
    extract-xcode)
        if [ $# -ne 2 ]; then
            print_error "Missing argument: project_path"
            show_usage
            exit 1
        fi
        extract_xcode_version "$2"
        ;;
    
    verify)
        if [ $# -ne 3 ]; then
            print_error "Missing arguments: changelog_path and project_path"
            show_usage
            exit 1
        fi
        
        CHANGELOG_VERSION=$(extract_version "$2")
        XCODE_VERSION=$(extract_xcode_version "$3")
        
        if verify_versions "$CHANGELOG_VERSION" "$XCODE_VERSION"; then
            exit 0
        else
            exit 1
        fi
        ;;
    
    *)
        print_error "Unknown command: $COMMAND"
        show_usage
        exit 1
        ;;
esac
