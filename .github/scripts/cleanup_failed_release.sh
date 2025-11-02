#!/bin/bash

# Usage4Claude - Cleanup Failed Release
# This script cleans up tags and releases when build fails

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
# Delete git tag
# ============================================
delete_tag() {
    local tag="$1"
    
    print_info "Checking if tag exists: $tag"
    
    # Check if tag exists locally
    if git rev-parse "$tag" >/dev/null 2>&1; then
        print_info "Deleting local tag: $tag"
        git tag -d "$tag" || print_warning "Failed to delete local tag"
    else
        print_info "Local tag not found: $tag"
    fi
    
    # Check if tag exists on remote
    if git ls-remote --tags origin | grep -q "refs/tags/$tag"; then
        print_info "Deleting remote tag: $tag"
        git push --delete origin "$tag" || print_warning "Failed to delete remote tag"
    else
        print_info "Remote tag not found: $tag"
    fi
}

# ============================================
# Delete GitHub release
# ============================================
delete_release() {
    local tag="$1"
    
    print_info "Checking if release exists: $tag"
    
    # Use GitHub CLI to check and delete release
    if gh release view "$tag" >/dev/null 2>&1; then
        print_info "Deleting GitHub release: $tag"
        gh release delete "$tag" --yes || print_warning "Failed to delete release"
    else
        print_info "Release not found: $tag"
    fi
}

# ============================================
# Main cleanup function
# ============================================
cleanup() {
    local version="$1"
    local tag="v$version"
    
    print_info "Starting cleanup for version: $version"
    echo ""
    
    # Delete release first (if exists)
    delete_release "$tag"
    echo ""
    
    # Then delete tag
    delete_tag "$tag"
    echo ""
    
    print_success "Cleanup completed"
}

# ============================================
# Main Script
# ============================================

show_usage() {
    echo "Usage: $0 <version>"
    echo ""
    echo "Arguments:"
    echo "  version    Version number to clean up (e.g., 1.1.3)"
    echo ""
    echo "Example:"
    echo "  $0 1.1.3"
    echo ""
    echo "This will:"
    echo "  - Delete GitHub release v1.1.3 (if exists)"
    echo "  - Delete git tag v1.1.3 (local and remote)"
}

# Check arguments
if [ $# -ne 1 ]; then
    show_usage
    exit 1
fi

VERSION="$1"

# Validate version format
if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    print_error "Invalid version format: $VERSION"
    print_info "Expected format: X.Y.Z (e.g., 1.1.3)"
    exit 1
fi

cleanup "$VERSION"
