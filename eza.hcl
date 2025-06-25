description = "Modern, maintained replacement for ls"
homepage = "https://github.com/eza-community/eza"
binaries = ["eza"]
test = "eza --help"

version "0.21.5" {
  auto-version {
    github-release = "eza-community/eza"
  }
}

# Source URL from Homebrew (may need manual adjustment for multi-platform)
# Original: https://github.com/eza-community/eza/archive/refs/tags/v0.21.5.tar.gz

# Note: This is a basic template. You'll likely need to:
# 1. Add platform-specific source URLs for linux/darwin
# 2. Add proper binary extraction if it's in a tar.gz/zip
# 3. Verify the binary name matches the package name
# 4. Test the package works correctly
# 5. Add proper sha256sums for multiple versions/platforms

# Homebrew checksum: 85aff87a87bc66130a43106ee64fdefa572d709f5e1ae33d7ef1de76329d2950

# Example multi-platform structure (uncomment and modify as needed):
# darwin {
#   source = "https://github.com/eza-community/eza/releases/download/v${version}/eza-${version}-${os}-${arch}.tar.gz"
# }
# 
# linux {
#   source = "https://github.com/eza-community/eza/releases/download/v${version}/eza-${version}-${os}-${arch}.tar.gz"
# }
# 
# sha256sums = {
#   "https://example.com/file.tar.gz": "85aff87a87bc66130a43106ee64fdefa572d709f5e1ae33d7ef1de76329d2950",
# }
