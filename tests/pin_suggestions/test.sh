#!/usr/bin/env bash
# Living spec for the pinning policy shipped in the pin-suggestions reusable workflow.
#
# Each scenario writes one `uses:` line into a throwaway workflow, applies the policy
# with pinact exactly as the reusable workflow does, and checks the resulting line.
# Expected SHAs come from `git ls-remote` on exact release tags, which don't move.
#
# Requires: pinact 4.0.0 on PATH (or PINACT=/path/to/pinact) and GITHUB_TOKEN.

set -euo pipefail

# Must match the pinact version bundled by the pinact-action release the workflow pins.
readonly PINACT_VERSION="4.0.0"

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
readonly WORKFLOW="$repo_root/.github/workflows/pin-suggestions.yml"
pinact="${PINACT:-pinact}"
work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT
failures=0

fail_setup() {
  echo "setup error: $1" >&2
  exit 2
}

check_prerequisites() {
  command -v "$pinact" >/dev/null 2>&1 || fail_setup "pinact not found; install pinact $PINACT_VERSION or set PINACT"
  "$pinact" -v | grep -q "version $PINACT_VERSION\$" || fail_setup "expected pinact $PINACT_VERSION, got: $("$pinact" -v)"
  [[ -n "${GITHUB_TOKEN:-}" ]] || fail_setup "GITHUB_TOKEN is required to resolve tags"
  [[ -f "$WORKFLOW" ]] || fail_setup "reusable workflow not found at $WORKFLOW"
}

# The policy lives inline in the reusable workflow between marker comments, so the
# workflow stays the single source of truth. Strip the block's shared indentation.
extract_policy() {
  awk '
    /# BEGIN pinning-policy/ { inside = 1; next }
    /# END pinning-policy/   { inside = 0 }
    inside { lines[n++] = $0 }
    END {
      min = -1
      for (i = 0; i < n; i++) {
        if (lines[i] ~ /^[[:space:]]*$/) continue
        match(lines[i], /^ */)
        if (min < 0 || RLENGTH < min) min = RLENGTH
      }
      for (i = 0; i < n; i++) print substr(lines[i], min + 1)
    }
  ' "$WORKFLOW" > "$work_dir/policy.yaml"
  [[ -s "$work_dir/policy.yaml" ]] || fail_setup "no pinning-policy block found in $WORKFLOW"
}

# Version comment verification is a pinact-action input, not part of the config file,
# so read it from the workflow too.
pinact_flags=()
read_verify_setting() {
  if grep -Eq '^[[:space:]]+verify: "true"' "$WORKFLOW"; then
    pinact_flags+=(--verify)
  fi
}

# Given a `uses:` value, apply the policy and print the resulting `uses:` value.
# Mirrors the reusable workflow: --config <policy>, plus --verify when it is enabled.
apply_policy() {
  local file="$work_dir/workflow.yml"
  printf 'jobs:\n  t:\n    steps:\n      - uses: %s\n' "$1" > "$file"
  if ! "$pinact" --config "$work_dir/policy.yaml" run ${pinact_flags[@]+"${pinact_flags[@]}"} "$file" > "$work_dir/pinact.log" 2>&1; then
    echo "pinact failed:" >&2
    cat "$work_dir/pinact.log" >&2
    return 1
  fi
  sed -n 's/^      - uses: //p' "$file"
}

scenario() {
  local description="$1" given="$2" expected="$3" actual
  if actual="$(apply_policy "$given")" && [[ "$actual" == "$expected" ]]; then
    echo "ok   - $description"
  else
    echo "FAIL - $description"
    echo "       given:    $given"
    echo "       expected: $expected"
    echo "       actual:   ${actual:-<pinact error>}"
    failures=$((failures + 1))
  fi
}

check_prerequisites
extract_policy
read_verify_setting

scenario "Given a third-party mutable reference, when the policy is applied, then it is pinned to the tag's commit with its release as the version comment" \
  "amannn/action-semantic-pull-request@v6.1.1" \
  "amannn/action-semantic-pull-request@48f256284bd46cdaab1048c3721360e808335d50 # v6.1.1"

scenario "Given a GitHub-owned actions/* reference, when the policy is applied, then it is pinned like any third party" \
  "actions/checkout@v5.0.0" \
  "actions/checkout@08c6903cd8c0fde910a37f88322edcfb5dd907a8 # v5.0.0"

scenario "Given an internal ecobee action, when the policy is applied, then it is left unchanged without error" \
  "ecobee/some-internal-repo/setup@v1" \
  "ecobee/some-internal-repo/setup@v1"

# 08c6903 is v5.0.0; v5.0.1 is a different commit.
scenario "Given a pinned reference whose version comment names the wrong release, when the policy is applied, then the comment is corrected" \
  "actions/checkout@08c6903cd8c0fde910a37f88322edcfb5dd907a8 # v5.0.1" \
  "actions/checkout@08c6903cd8c0fde910a37f88322edcfb5dd907a8 # v5.0.0"

scenario "Given a pinned reference with no version comment, when the policy is applied, then the release is added as the version comment" \
  "actions/checkout@08c6903cd8c0fde910a37f88322edcfb5dd907a8" \
  "actions/checkout@08c6903cd8c0fde910a37f88322edcfb5dd907a8 # v5.0.0"

scenario "Given an already pinned reference with a correct version comment, when the policy is applied again, then nothing changes" \
  "actions/checkout@08c6903cd8c0fde910a37f88322edcfb5dd907a8 # v5.0.0" \
  "actions/checkout@08c6903cd8c0fde910a37f88322edcfb5dd907a8 # v5.0.0"

if (( failures > 0 )); then
  echo "$failures scenario(s) failed"
  exit 1
fi
echo "all scenarios passed"
