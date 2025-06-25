#!/bin/bash
# Generate Hermit HCL package definitions from Homebrew packages

set -euo pipefail

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
    fi
    
    # Create the HCL file
    cat > "${name}.hcl" << EOF
description = "${desc}"
homepage = "${homepage}"
binaries = ["${name}"]
test = "${name} --help"

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

# Source URL from Homebrew (may need manual adjustment for multi-platform)
# Original: ${source_url}

# Note: This is a basic template. You'll likely need to:
# 1. Add platform-specific source URLs for linux/darwin
# 2. Add proper binary extraction if it's in a tar.gz/zip
# 3. Verify the binary name matches the package name
# 4. Test the package works correctly
# 5. Add proper sha256sums for multiple versions/platforms

# Homebrew checksum: ${checksum}

# Example multi-platform structure (uncomment and modify as needed):
# darwin {
#   source = "https://github.com/${github_repo}/releases/download/v\${version}/${name}-\${version}-\${os}-\${arch}.tar.gz"
# }
# 
# linux {
#   source = "https://github.com/${github_repo}/releases/download/v\${version}/${name}-\${version}-\${os}-\${arch}.tar.gz"
# }
# 
# sha256sums = {
#   "https://example.com/file.tar.gz": "${checksum}",
# }
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
