#!/bin/bash
# Generate Hermit HCL package definitions from Homebrew packages
# Enhanced with GitHub CLI integration for automatic source URL detection

set -euo pipefail

# Check for required tools
if ! command -v brew &> /dev/null; then
    echo "Error: brew is required but not installed" >&2
    exit 1
fi

if ! command -v gh &> /dev/null; then
    echo "Error: gh (GitHub CLI) is required but not installed" >&2
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo "Error: jq is required but not installed" >&2
    exit 1
fi

# Function to detect binary names from GitHub release assets
detect_binaries() {
    local github_repo="$1"
    local package_name="$2"
    local assets=("${@:3}")
    
    local binaries=()
    
    # Try to find executables in common patterns
    for asset in "${assets[@]}"; do
        asset_name=$(basename "$asset")
        # Look for files that might contain binaries
        if [[ "$asset_name" =~ \.(tar\.gz|tgz|zip)$ ]]; then
            # Common binary name patterns
            local potential_binary=""
            if [[ "$asset_name" =~ ^([^-]+)- ]]; then
                potential_binary="${BASH_REMATCH[1]}"
            elif [[ "$asset_name" =~ ^([^_]+)_ ]]; then
                potential_binary="${BASH_REMATCH[1]}"
            else
                potential_binary="$package_name"
            fi
            
            if [[ ! " ${binaries[*]} " =~ " ${potential_binary} " ]]; then
                binaries+=("$potential_binary")
            fi
        fi
    done
    
    # Default to package name if no binaries detected
    if [ ${#binaries[@]} -eq 0 ]; then
        binaries=("$package_name")
    fi
    
    printf '%s\n' "${binaries[@]}"
}

# Function to generate HCL for a single package
generate_package_hcl() {
    local package_name="$1"
    local brew_info
    
    echo "Generating HCL for: $package_name"
    
    # Get package info from brew
    brew_info=$(brew info --json=v2 "$package_name" | jq '.formulae[0]')
    
    if [ "$brew_info" = "null" ]; then
        echo "Warning: Package $package_name not found" >&2
        return 1
    fi
    
    local name=$(echo "$brew_info" | jq -r '.name')
    local version=$(echo "$brew_info" | jq -r '.versions.stable')
    local desc=$(echo "$brew_info" | jq -r '.desc')
    local homepage=$(echo "$brew_info" | jq -r '.homepage')
    local source_url=$(echo "$brew_info" | jq -r '.urls.stable.url')
    local checksum=$(echo "$brew_info" | jq -r '.urls.stable.checksum')
    
    # Try to detect if it's a GitHub release
    local github_repo=""
    if [[ "$source_url" =~ github\.com/([^/]+/[^/]+) ]]; then
        github_repo="${BASH_REMATCH[1]}"
        # Remove .git suffix if present
        github_repo="${github_repo%.git}"
    elif [[ "$homepage" =~ github\.com/([^/]+/[^/]+) ]]; then
        github_repo="${BASH_REMATCH[1]}"
        github_repo="${github_repo%.git}"
    fi
    
    # Get GitHub release info if we have a repo
    local release_info=""
    local release_assets=()
    if [ -n "$github_repo" ]; then
        echo "  Fetching GitHub release info for $github_repo..."
        if release_info=$(gh api "/repos/$github_repo/releases/latest" 2>/dev/null); then
            mapfile -t release_assets < <(echo "$release_info" | jq -r '.assets[].browser_download_url')
        else
            echo "    Warning: Could not fetch release info for $github_repo"
        fi
    fi
    
    # Detect binary names
    local detected_binaries=()
    if [ ${#release_assets[@]} -gt 0 ]; then
        mapfile -t detected_binaries < <(detect_binaries "$github_repo" "$name" "${release_assets[@]}")
    else
        detected_binaries=("$name")
    fi
    
    # Create the HCL file
    local binaries_hcl=""
    if [ ${#detected_binaries[@]} -eq 1 ]; then
        binaries_hcl="binaries = [\"${detected_binaries[0]}\"]"
    else
        binaries_hcl="binaries = ["
        for i in "${!detected_binaries[@]}"; do
            if [ $i -eq 0 ]; then
                binaries_hcl="${binaries_hcl}\"${detected_binaries[i]}\""
            else
                binaries_hcl="${binaries_hcl}, \"${detected_binaries[i]}\""
            fi
        done
        binaries_hcl="${binaries_hcl}]"
    fi
    
    cat > "${name}.hcl" << EOF
description = "${desc}"
homepage = "${homepage}"
${binaries_hcl}
test = "${detected_binaries[0]} --help"

version "${version}" {
EOF

    # Add auto-version if it's a GitHub repo
    if [ -n "$github_repo" ]; then
        cat >> "${name}.hcl" << EOF
  auto-version {
    github-release = "${github_repo}"
  }
EOF
    fi

    cat >> "${name}.hcl" << EOF
}
EOF

    # Add detected release assets as comments
    if [ ${#release_assets[@]} -gt 0 ]; then
        cat >> "${name}.hcl" << EOF

# GitHub release assets found:
EOF
        for asset in "${release_assets[@]}"; do
            echo "# - $asset" >> "${name}.hcl"
        done
        
        # Try to auto-generate source patterns
        echo "" >> "${name}.hcl"
        echo "# Auto-detected source patterns:" >> "${name}.hcl"
        
        # Look for common patterns in asset names
        local has_darwin_amd64=false
        local has_darwin_arm64=false
        local has_linux_amd64=false
        local has_linux_arm64=false
        local sample_pattern=""
        
        for asset in "${release_assets[@]}"; do
            asset_name=$(basename "$asset")
            if [[ "$asset_name" =~ [Dd]arwin.*[Xx]86_64|[Dd]arwin.*amd64|macos.*x64 ]]; then
                has_darwin_amd64=true
                sample_pattern="$asset"
            elif [[ "$asset_name" =~ [Dd]arwin.*[Aa]rm64|[Dd]arwin.*aarch64|macos.*arm64 ]]; then
                has_darwin_arm64=true
            elif [[ "$asset_name" =~ [Ll]inux.*[Xx]86_64|[Ll]inux.*amd64 ]]; then
                has_linux_amd64=true
            elif [[ "$asset_name" =~ [Ll]inux.*[Aa]rm64|[Ll]inux.*aarch64 ]]; then
                has_linux_arm64=true
            fi
        done
        
        if [ -n "$sample_pattern" ]; then
            # Try to create a pattern by replacing version and platform info
            local pattern_url="$sample_pattern"
            pattern_url="${pattern_url/$version/\${version}}"
            pattern_url="${pattern_url//Darwin/\${os}}"
            pattern_url="${pattern_url//darwin/\${os}}"
            pattern_url="${pattern_url//Linux/\${os}}"
            pattern_url="${pattern_url//linux/\${os}}"
            pattern_url="${pattern_url//x86_64/\${arch}}"
            pattern_url="${pattern_url//amd64/\${arch}}"
            
            cat >> "${name}.hcl" << EOF
# source = "$pattern_url"

# Platform-specific variables may be needed:
# platform "darwin" { vars = { "os": "Darwin" } }
# platform "linux" { vars = { "os": "Linux" } }
# platform "amd64" { vars = { "arch": "x86_64" } }
# platform "arm64" { vars = { "arch": "arm64" } }
EOF
        fi
    fi

    cat >> "${name}.hcl" << EOF

# Original Homebrew info:
# Source URL: ${source_url}
# Checksum: ${checksum}

# TODO:
# 1. Add proper source URL with platform variables
# 2. Add platform-specific configurations
# 3. Add sha256sums for all supported platforms
# 4. Test the package installation
# 5. Verify binary extraction and paths
EOF

    echo "Generated: ${name}.hcl"
}

# Main script
main() {
    if [ $# -eq 0 ]; then
        echo "Usage: $0 <package1> [package2] [package3] ..."
        echo "       $0 --all    # Generate for all installed brew packages"
        echo ""
        echo "Examples:"
        echo "  $0 atuin eza fish"
        echo "  $0 --all"
        exit 1
    fi
    
    if [ "$1" = "--all" ]; then
        echo "Generating HCL files for all installed Homebrew packages..."
        mapfile -t packages < <(brew list --formula)
        
        for package in "${packages[@]}"; do
            generate_package_hcl "$package" || echo "Failed to generate HCL for $package"
            echo ""
        done
    else
        for package in "$@"; do
            generate_package_hcl "$package"
            echo ""
        done
    fi
    
    echo "Done! Remember to:"
    echo "1. Review and edit the generated .hcl files"
    echo "2. Add proper platform-specific URLs and checksums"
    echo "3. Test the packages work with hermit"
    echo "4. Commit them to your hermit packages repository"
}

main "$@"
