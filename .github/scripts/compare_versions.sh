#!/bin/bash

# Usage4Claude - Version Comparison and Validation
# This script compares semantic versions and validates new releases

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# ============================================
# Helper Functions
# ============================================

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# ============================================
# Get latest published version from GitHub
# ============================================
get_latest_published_version() {
    # Use gh CLI to get latest published release
    # Exclude drafts and pre-releases
    local latest=$(gh release list \
        --exclude-drafts \
        --exclude-pre-releases \
        --limit 1 \
        --json tagName \
        --jq '.[0].tagName' 2>/dev/null || echo "")

    if [ -z "$latest" ]; then
        # No releases found
        echo "0.0.0"
        return
    fi

    # Remove 'v' prefix if exists
    echo "${latest#v}"
}

# ============================================
# Compare semantic versions
# Returns: 1 if v1 > v2, 0 if equal, -1 if v1 < v2
# ============================================
compare_semver() {
    local v1="$1"
    local v2="$2"

    # Handle special case: 0.0.0 (no previous version)
    if [[ "$v2" == "0.0.0" ]]; then
        echo "1"
        return
    fi

    # Strip pre-release suffix if exists (e.g., 1.0.0-beta -> 1.0.0)
    v1=$(echo "$v1" | cut -d'-' -f1)
    v2=$(echo "$v2" | cut -d'-' -f1)

    # Split version numbers
    IFS='.' read -r -a ver1 <<< "$v1"
    IFS='.' read -r -a ver2 <<< "$v2"

    # Compare major version
    if [[ ${ver1[0]} -gt ${ver2[0]} ]]; then
        echo "1"
        return
    elif [[ ${ver1[0]} -lt ${ver2[0]} ]]; then
        echo "-1"
        return
    fi

    # Compare minor version
    if [[ ${ver1[1]} -gt ${ver2[1]} ]]; then
        echo "1"
        return
    elif [[ ${ver1[1]} -lt ${ver2[1]} ]]; then
        echo "-1"
        return
    fi

    # Compare patch version
    if [[ ${ver1[2]} -gt ${ver2[2]} ]]; then
        echo "1"
        return
    elif [[ ${ver1[2]} -lt ${ver2[2]} ]]; then
        echo "-1"
        return
    fi

    # Versions are equal
    echo "0"
}

# ============================================
# Validate new version against published releases
# ============================================
validate_new_version() {
    local new_version="$1"
    local is_test_mode="${2:-false}"

    print_info "Validating version: $new_version"

    # Skip validation in test mode
    if [[ "$is_test_mode" == "true" ]]; then
        print_warning "Test mode - skipping online version check"
        return 0
    fi

    # Get latest published version
    print_info "Fetching latest published release..."
    local latest_version=$(get_latest_published_version)

    # Handle first release case
    if [[ "$latest_version" == "0.0.0" ]]; then
        print_success "First release detected - no version comparison needed"
        return 0
    fi

    print_info "Latest published version: $latest_version"
    print_info "New version: $new_version"

    # Compare versions
    local result=$(compare_semver "$new_version" "$latest_version")

    if [[ $result -eq 1 ]]; then
        print_success "Version validation passed: $new_version > $latest_version"
        return 0
    elif [[ $result -eq 0 ]]; then
        print_error "Version $new_version already exists!"
        echo ""
        echo "The new version must be greater than the latest published version."
        echo "Latest: $latest_version"
        echo "New: $new_version"
        return 1
    else
        print_error "New version ($new_version) is less than latest published version ($latest_version)!"
        echo ""
        echo "Version numbers must increase according to semantic versioning."
        echo "Latest: $latest_version"
        echo "New: $new_version"
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
    echo "  get-latest                     Get latest published version"
    echo "  compare <v1> <v2>              Compare two versions"
    echo "  validate <version> [is_test]   Validate new version against published releases"
    echo ""
    echo "Examples:"
    echo "  $0 get-latest"
    echo "  $0 compare 1.2.0 1.1.5"
    echo "  $0 validate 1.6.0"
    echo "  $0 validate 1.6.0 true"
}

# Check arguments
if [ $# -eq 0 ]; then
    show_usage
    exit 1
fi

COMMAND="$1"

case "$COMMAND" in
    get-latest)
        get_latest_published_version
        ;;

    compare)
        if [ $# -ne 3 ]; then
            print_error "Missing arguments: v1 and v2"
            show_usage
            exit 1
        fi
        compare_semver "$2" "$3"
        ;;

    validate)
        if [ $# -lt 2 ]; then
            print_error "Missing argument: version"
            show_usage
            exit 1
        fi

        IS_TEST_MODE="${3:-false}"

        if validate_new_version "$2" "$IS_TEST_MODE"; then
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
