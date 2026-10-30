#!/usr/bin/env bash
# Living spec for the pin-suggestions reusable workflow.
#
# Each scenario writes one `uses:` line into a throwaway workflow, runs pinact the way
# pinact-action does in review mode, and checks what the pull request author would see
# on that line: a suggested change, an error comment, or nothing.
# Expected SHAs come from `git ls-remote` on exact release tags, which don't move.
#
# Requires pinact $PINACT_VERSION on PATH (or PINACT=/path/to/pinact), jq, and GITHUB_TOKEN.

set -euo pipefail

# Must match the pinact bundled by the pinact-action release that pin-suggestions.yml pins.
# The test workflow installs this version.
readonly PINACT_VERSION="4.0.0"

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

setup() {
  [[ -f "$WORKFLOW" ]] || fail_setup "reusable workflow not found at $WORKFLOW"
  [[ -n "${GITHUB_TOKEN:-}" ]] || fail_setup "GITHUB_TOKEN is required to resolve tags"
  command -v jq >/dev/null 2>&1 || fail_setup "jq not found"
  command -v "$pinact" >/dev/null 2>&1 || fail_setup "pinact not found; install pinact $PINACT_VERSION or set PINACT"
  "$pinact" -v | grep -q "version $PINACT_VERSION\$" || fail_setup "expected pinact $PINACT_VERSION, got: $("$pinact" -v)"

  # Version comment verification is a pinact-action input, so read it from the workflow.
  if grep -Eq '^[[:space:]]+PINACT_VERIFY:[[:space:]]+"true"' "$WORKFLOW"; then
    pinact_flags+=(--verify)
  fi
  extract_policy
}

# Given a `uses:` value, print what the review shows on that line:
# "suggest: <uses value>", "error: <reason>", or nothing.
review_of() {
  printf 'jobs:\n  t:\n    steps:\n      - uses: %s\n' "$1" > "$work_dir/workflow.yml"
  # pinact exits non-zero whenever it has findings, so judge it by its SARIF output.
  (
    cd "$work_dir" || exit 1
    "$pinact" --config policy.yaml run --fix --format sarif \
      ${pinact_flags[@]+"${pinact_flags[@]}"} workflow.yml 2> pinact.log || true
  ) > "$work_dir/review.sarif"
  if ! jq -e '.runs' "$work_dir/review.sarif" >/dev/null 2>&1; then
    echo "pinact produced no SARIF:" >&2
    cat "$work_dir/pinact.log" >&2
    return 1
  fi
  jq -r '
    .runs[0].results[]? |
    if .fixes then
      "suggest: " + (.fixes[0].artifactChanges[0].replacements[0].insertedContent.text | sub("^ *- uses: "; ""))
    else
      "error: " + (.message.text | sub("^failed to handle a line: "; ""))
    end
  ' "$work_dir/review.sarif"
}

scenario() {
  local description="$1" given="$2" expected="$3" actual
  actual="$(review_of "$given" || echo "<pinact failed>")"
  if [[ "$actual" == "$expected" ]]; then
    echo "ok   - $description"
  else
    echo "FAIL - $description"
    echo "       given:    $given"
    echo "       expected: ${expected:-<nothing>}"
    echo "       actual:   ${actual:-<nothing>}"
    failures=$((failures + 1))
  fi
}

setup

scenario "Given a third-party mutable reference, when the pull request is reviewed, then a pin to the tag's commit is suggested with its release as the version comment" \
  "amannn/action-semantic-pull-request@v6.1.1" \
  "suggest: amannn/action-semantic-pull-request@48f256284bd46cdaab1048c3721360e808335d50 # v6.1.1"

scenario "Given a GitHub-owned actions/* reference, when the pull request is reviewed, then a pin is suggested like any third party" \
  "actions/checkout@v5.0.0" \
  "suggest: actions/checkout@08c6903cd8c0fde910a37f88322edcfb5dd907a8 # v5.0.0"

scenario "Given an internal ecobee action, when the pull request is reviewed, then nothing is posted" \
  "ecobee/some-internal-repo/setup@v1" \
  ""

scenario "Given an internal action whose owner is written in another case, when the pull request is reviewed, then nothing is posted" \
  "Ecobee/some-internal-repo/setup@v1" \
  ""

# 08c6903 is v5.0.0; v5.0.1 is a different commit. The SHA stays; only the label changes.
scenario "Given a release SHA whose version comment names a different release, when the pull request is reviewed, then correcting the comment to the SHA's real release is suggested" \
  "actions/checkout@08c6903cd8c0fde910a37f88322edcfb5dd907a8 # v5.0.1" \
  "suggest: actions/checkout@08c6903cd8c0fde910a37f88322edcfb5dd907a8 # v5.0.0"

# 3ba5ee6 is a 2022 commit that no release tag points to, e.g. an imposter commit.
scenario "Given a SHA that is not any release, labelled with a version comment, when the pull request is reviewed, then it is flagged as an error with no suggestion" \
  "actions/checkout@3ba5ee6fac7e0e30e2ea884e236f282d3a775891 # v5.0.0" \
  "error: action_version must be equal to commit_hash_of_version_annotation"

scenario "Given a reference that can't be resolved, when the pull request is reviewed, then an error with the reason is posted" \
  "actions/this-action-does-not-exist@v1" \
  "error: get a reference: GET https://api.github.com/repos/actions/this-action-does-not-exist/commits/v1: 404 Not Found []"

scenario "Given a pinned reference with no version comment, when the pull request is reviewed, then adding the release as the version comment is suggested" \
  "actions/checkout@08c6903cd8c0fde910a37f88322edcfb5dd907a8" \
  "suggest: actions/checkout@08c6903cd8c0fde910a37f88322edcfb5dd907a8 # v5.0.0"

scenario "Given a correctly pinned reference, when the pull request is reviewed, then nothing is posted" \
  "actions/checkout@08c6903cd8c0fde910a37f88322edcfb5dd907a8 # v5.0.0" \
  ""

if (( failures > 0 )); then
  echo "$failures scenario(s) failed"
  exit 1
fi
echo "all scenarios passed"
