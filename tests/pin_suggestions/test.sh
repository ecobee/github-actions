#!/usr/bin/env bash
# Living spec for the pin-suggestions reusable workflow.
#
# Each scenario writes one `uses:` line into a throwaway workflow and runs pinact the
# way the reusable workflow does: once to apply the pinning policy (the suggestion a
# developer sees), and once in check mode to produce the warning annotations.
# Expected SHAs come from `git ls-remote` on exact release tags, which don't move.
#
# Requires pinact on PATH (or PINACT=/path/to/pinact) at the version the workflow pins,
# and GITHUB_TOKEN.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
readonly WORKFLOW="$repo_root/.github/workflows/pin-suggestions.yml"
pinact="${PINACT:-pinact}"
work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT
failures=0
pinact_flags=()

fail_setup() {
  echo "setup error: $1" >&2
  exit 2
}

# Read a job env value (e.g. PINACT_VERSION) from the reusable workflow.
workflow_env() {
  sed -n "s/^[[:space:]]*$1:[[:space:]]*\"\{0,1\}\([^\"[:space:]]*\)\"\{0,1\}.*/\1/p" "$WORKFLOW" | head -n 1
}

# Copy the block between `# BEGIN <name>` and `# END <name>` out of the workflow,
# stripping its shared indentation, so the workflow stays the single source of truth.
extract_block() {
  local name="$1" out="$2"
  awk -v begin="# BEGIN $name" -v end="# END $name" '
    index($0, begin) { inside = 1; next }
    index($0, end)   { inside = 0 }
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
  ' "$WORKFLOW" > "$out"
  [[ -s "$out" ]] || fail_setup "no '$name' block found in $WORKFLOW"
}

setup() {
  [[ -f "$WORKFLOW" ]] || fail_setup "reusable workflow not found at $WORKFLOW"
  [[ -n "${GITHUB_TOKEN:-}" ]] || fail_setup "GITHUB_TOKEN is required to resolve tags"

  local version
  version="$(workflow_env PINACT_VERSION)"
  [[ -n "$version" ]] || fail_setup "PINACT_VERSION not set in $WORKFLOW"
  command -v "$pinact" >/dev/null 2>&1 || fail_setup "pinact not found; install pinact $version or set PINACT"
  "$pinact" -v | grep -q "version $version\$" || fail_setup "expected pinact $version, got: $("$pinact" -v)"

  [[ "$(workflow_env PINACT_VERIFY)" == "true" ]] && pinact_flags+=(--verify)

  extract_block pinning-policy "$work_dir/policy.yaml"
  extract_block pinact-annotations "$work_dir/annotate.awk"
}

write_workflow() {
  printf 'jobs:\n  t:\n    steps:\n      - uses: %s\n' "$1" > "$work_dir/workflow.yml"
}

run_pinact() {
  "$pinact" --config "$work_dir/policy.yaml" run ${pinact_flags[@]+"${pinact_flags[@]}"} "$@" workflow.yml
}

# Given a `uses:` value, print the `uses:` value the developer is offered.
suggested_pin() {
  write_workflow "$1"
  if ! (cd "$work_dir" && run_pinact > pinact.log 2>&1); then
    echo "pinact failed:" >&2
    cat "$work_dir/pinact.log" >&2
    return 1
  fi
  sed -n 's/^      - uses: //p' "$work_dir/workflow.yml"
}

# Given a `uses:` value, print the warning annotations the check step emits.
annotations() {
  write_workflow "$1"
  (cd "$work_dir" && { run_pinact --fix=false 2>&1 || true; } | awk -f annotate.awk)
}

report() {
  local description="$1" given="$2" expected="$3" actual="$4"
  if [[ "$actual" == "$expected" ]]; then
    echo "ok   - $description"
  else
    echo "FAIL - $description"
    echo "       given:    $given"
    echo "       expected: $expected"
    echo "       actual:   ${actual:-<nothing>}"
    failures=$((failures + 1))
  fi
}

scenario() {
  report "$1" "$2" "$3" "$(suggested_pin "$2" || true)"
}

annotation_scenario() {
  report "$1" "$2" "$3" "$(annotations "$2")"
}

setup

scenario "Given a third-party mutable reference, when the policy is applied, then it is pinned to the tag's commit with its release as the version comment" \
  "amannn/action-semantic-pull-request@v6.1.1" \
  "amannn/action-semantic-pull-request@48f256284bd46cdaab1048c3721360e808335d50 # v6.1.1"

scenario "Given a GitHub-owned actions/* reference, when the policy is applied, then it is pinned like any third party" \
  "actions/checkout@v5.0.0" \
  "actions/checkout@08c6903cd8c0fde910a37f88322edcfb5dd907a8 # v5.0.0"

scenario "Given an internal ecobee action, when the policy is applied, then it is left unchanged without error" \
  "ecobee/some-internal-repo/setup@v1" \
  "ecobee/some-internal-repo/setup@v1"

scenario "Given an internal action whose owner is written in another case, when the policy is applied, then it is still left unchanged" \
  "Ecobee/some-internal-repo/setup@v1" \
  "Ecobee/some-internal-repo/setup@v1"

# 08c6903 is v5.0.0; v5.0.1 is a different commit.
scenario "Given a pinned reference whose version comment names the wrong release, when the policy is applied, then the comment is corrected" \
  "actions/checkout@08c6903cd8c0fde910a37f88322edcfb5dd907a8 # v5.0.1" \
  "actions/checkout@08c6903cd8c0fde910a37f88322edcfb5dd907a8 # v5.0.0"

annotation_scenario "Given a pinned reference whose version comment names the wrong release, when the workflow checks it, then it warns on that line so the SHA gets a second look" \
  "actions/checkout@08c6903cd8c0fde910a37f88322edcfb5dd907a8 # v5.0.1" \
  "::warning file=workflow.yml,line=4,title=Version comment mismatch::The version comment names a different release than the pinned SHA. Check the SHA itself before accepting a suggestion."

annotation_scenario "Given a reference that can't be resolved, when the workflow checks it, then it warns on that line with pinact's reason" \
  "actions/this-action-does-not-exist@v1" \
  "::warning file=workflow.yml,line=4,title=Could not check pin::get a reference: GET https://api.github.com/repos/actions/this-action-does-not-exist/commits/v1: 404 Not Found []"

annotation_scenario "Given a correctly pinned reference, when the workflow checks it, then there are no warnings" \
  "actions/checkout@08c6903cd8c0fde910a37f88322edcfb5dd907a8 # v5.0.0" \
  ""

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
