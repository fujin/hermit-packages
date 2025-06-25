description = "Improved shell history for zsh, bash, fish and nushell"
homepage = "https://atuin.sh/"
binaries = ["atuin"]
test = "atuin --help"

version "18.6.1" {
  auto-version {
    github-release = "atuinsh/atuin"
  }
}

# Source URL from Homebrew (may need manual adjustment for multi-platform)
# Original: https://github.com/atuinsh/atuin/archive/refs/tags/v18.6.1.tar.gz

# Note: This is a basic template. You'll likely need to:
# 1. Add platform-specific source URLs for linux/darwin
# 2. Add proper binary extraction if it's in a tar.gz/zip
# 3. Verify the binary name matches the package name
# 4. Test the package works correctly
# 5. Add proper sha256sums for multiple versions/platforms

# Homebrew checksum: aba26698471ef7ad2757416d01fcc327d3bd800c58cc3fcae638e625524e1b40

# Example multi-platform structure (uncomment and modify as needed):
# darwin {
#   source = "https://github.com/atuinsh/atuin/releases/download/v${version}/atuin-${version}-${os}-${arch}.tar.gz"
# }
# 
# linux {
#   source = "https://github.com/atuinsh/atuin/releases/download/v${version}/atuin-${version}-${os}-${arch}.tar.gz"
# }
# 
# sha256sums = {
#   "https://example.com/file.tar.gz": "aba26698471ef7ad2757416d01fcc327d3bd800c58cc3fcae638e625524e1b40",
# }
