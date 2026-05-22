#!/usr/bin/env bash
set -euo pipefail

# Simple release script for github-actions
# Usage: ./scripts/release.sh [version]

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

error() {
  echo -e "${RED}ERROR: $1${NC}" >&2
  exit 1
}

info() {
  echo -e "${GREEN}$1${NC}"
}

warn() {
  echo -e "${YELLOW}$1${NC}"
}

# Compare semver versions
# Returns 0 if $1 > $2, 1 otherwise
version_gt() {
  local ver1=$1
  local ver2=$2

  # Strip 'v' prefix if present
  ver1=${ver1#v}
  ver2=${ver2#v}

  # Split into major.minor.patch
  IFS='.' read -ra V1 <<< "$ver1"
  IFS='.' read -ra V2 <<< "$ver2"

  # Compare major
  if [[ ${V1[0]} -gt ${V2[0]} ]]; then return 0; fi
  if [[ ${V1[0]} -lt ${V2[0]} ]]; then return 1; fi

  # Compare minor
  if [[ ${V1[1]:-0} -gt ${V2[1]:-0} ]]; then return 0; fi
  if [[ ${V1[1]:-0} -lt ${V2[1]:-0} ]]; then return 1; fi

  # Compare patch
  if [[ ${V1[2]:-0} -gt ${V2[2]:-0} ]]; then return 0; fi

  return 1
}

# Validate semver format
validate_semver() {
  local version=$1
  if [[ ! $version =~ ^v?[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    error "Invalid version format: $version (expected: v1.2.3 or 1.2.3)"
  fi
}

main() {
  # Check we're on main branch
  local current_branch=$(git branch --show-current)
  if [[ "$current_branch" != "main" ]]; then
    error "Must be on 'main' branch to publish (currently on: $current_branch)"
  fi

  # Check working tree is clean
  if [[ -n $(git status --porcelain) ]]; then
    error "Working tree is not clean. Commit or stash changes first."
  fi

  # Fetch latest tags
  info "Fetching latest tags..."
  git fetch --tags

  # Get latest version tag
  local latest_tag=$(git tag -l "v*.*.*" | sort -V | tail -n1)

  if [[ -z "$latest_tag" ]]; then
    warn "No existing version tags found. This will be the first release."
    latest_tag="v0.0.0"
  else
    info "Latest version: $latest_tag"
  fi

  # Get new version
  local new_version="${1:-}"
  if [[ -z "$new_version" ]]; then
    echo ""
    read -p "Enter new version (e.g., v1.0.0): " new_version
  fi

  # Add 'v' prefix if missing
  if [[ ! $new_version =~ ^v ]]; then
    new_version="v${new_version}"
  fi

  # Validate format
  validate_semver "$new_version"

  # Check if tag already exists
  if git rev-parse "$new_version" >/dev/null 2>&1; then
    error "Tag $new_version already exists"
  fi

  # Validate new version is greater than latest
  if [[ "$latest_tag" != "v0.0.0" ]]; then
    if ! version_gt "$new_version" "$latest_tag"; then
      error "New version $new_version must be greater than $latest_tag"
    fi
  fi

  # Extract major version for major tag (e.g., v1 from v1.2.3)
  local major_version=$(echo "$new_version" | sed -E 's/^v([0-9]+)\..*/v\1/')

  echo ""
  info "Release Summary:"
  echo "  Previous: $latest_tag"
  echo "  New:      $new_version"
  echo "  Major:    $major_version (will be updated)"
  echo ""

  read -p "Create and push these tags? (y/N): " confirm
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    warn "Release cancelled"
    exit 0
  fi

  # Create and push version tag
  info "Creating tag $new_version..."
  git tag "$new_version"
  git push origin "$new_version"

  # Update major version tag
  info "Updating major version tag $major_version..."
  git tag -f "$major_version"
  git push -f origin "$major_version"

  echo ""
  info "✓ Release complete!"
  echo ""
  echo "Tags created:"
  echo "  - $new_version"
  echo "  - $major_version"
  echo ""
  echo "Teams can now use: @$major_version or @$new_version"
}

main "$@"
