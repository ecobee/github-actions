# github-actions

Collection of GitHub actions for ecobee. While the current examples are all composite run types, any github action style is welcome here!

| Action                                                                 |
| ---------------------------------------------------------------------- |
| [`ecobee/github-actions/go_build_artifact@v1`](./go_build_artifact) |
| [`ecobee/github-actions/go_test_and_lint@v1`](./go_test_and_lint)   |
| [`ecobee/github-actions/push_docker_gcr@v1`](./push_docker_gcr)     |
| [`ecobee/github-actions/publish_dx_dora_metrics@v1`](./publish_dx_dora_metrics_trunk_based) |

## Usage

See individual action directory for details on usage and examples.

- [Go Build artifact](../go_build_artifact) - builds golang binary and outputs build tag
- [Go Test and Lint](../go_test_and_lint) - runs golang tests, and lints with golangci-lint
- [Push Docker GCR](../push_docker_gcr) - creates docker file from repo's Dockerfile, pushed using supplied build tag
- [Publish DX DORA Metrics](../publish_dx_dora_metrics) - publishes deployment metrics to DX for DORA tracking
- [Pin suggestions](#pin-suggestions) - suggests SHA pins for GitHub Actions on pull requests

## Pin suggestions

SonarQube and Wiz flag workflow lines like `uses: actions/setup-go@v6` because a tag can be moved to different code. This reusable workflow comments on each such line your pull request adds with the pinned form, for example `uses: actions/setup-go@<sha> # v6.1.0`, which runs exactly what `@v6` runs today. Select "Add suggestion to batch" on each comment, then "Commit suggestions". It all happens in the browser, so nothing needs installing.

It's advisory: it never blocks your pull request and never commits for you. Internal `ecobee/` actions are left alone. Lines it can't pin get an error comment with the reason instead of a suggestion, for example a reference that doesn't exist or a SHA that isn't any release of that action.

Add this file to your repository as `.github/workflows/pin-suggestions.yml`:

```yaml
name: Pin suggestions

on:
  pull_request:
    paths:
      - .github/workflows/**
      - "**/action.yml"
      - "**/action.yaml"

permissions:
  contents: read
  pull-requests: write

jobs:
  suggest-pins:
    uses: ecobee/github-actions/.github/workflows/pin-suggestions.yml@v1
```

Don't make it a required check. Leaving it optional is what keeps it from blocking anyone.

### When the check shows as skipped

The job only runs on `pull_request` events opened from a branch in the same repository, and otherwise it shows as "Skipped" in the checks list without any comment. Pull requests from forks are skipped because GitHub gives them a read-only token, which can't post review comments. Other events such as `push`, `pull_request_target` or `merge_group` are skipped because suggestions need a pull request diff to attach to; `pull_request_target` is also unsafe here, since it would run with a write token against untrusted code. If you see "Skipped" on a pull request from your own repository, check that the caller workflow triggers on `pull_request` as shown above.

The check can still go red if something outside pinact fails, such as checkout or a runner timeout. Because the check isn't required, that never blocks a merge.

To keep pins current, let Dependabot bump them. It updates the SHA and version comment together. Group updates into one weekly pull request, and wait seven days after a release so a hijacked release has time to be caught. Don't ignore minor or patch updates, because pinned references would then never move.

```yaml
# .github/dependabot.yml
version: 2
updates:
  - package-ecosystem: github-actions
    directory: /
    schedule:
      interval: weekly
    cooldown:
      default-days: 7
    groups:
      github-actions:
        patterns: ["*"]
```

Maintainers: the pinning policy lives inline in [`pin-suggestions.yml`](.github/workflows/pin-suggestions.yml) and is specified by [`tests/pin_suggestions/test.sh`](tests/pin_suggestions/test.sh). Run the specs locally with the pinact version named in the spec on your `PATH` and `GITHUB_TOKEN=$(gh auth token) tests/pin_suggestions/test.sh`. When bumping pinact-action, update `PINACT_VERSION` in the spec and `PINACT_SHA256` in the test workflow to match the pinact it bundles.

## Versioning

This repository follows [semantic versioning](https://semver.org/). When using these actions in workflows:
- **Recommended:** `@v1` - automatically get non-breaking updates (patches and minor versions)
- **Pinned:** `@v1.0.0` - pin to a specific release version
- **Unstable:** `@main` - use latest code (not recommended for production)

### Creating Releases

For maintainers releasing new versions:

1. **Merge changes to main**
2. **Run the release script:**
   ```bash
   ./scripts/set-release-tag.sh v1.2.3
   ```
   The script will:
   - Validate you're on `main` with a clean working tree
   - Show the current latest version
   - Validate the new version is greater than the current version
   - Create and push both the version tag (`v1.2.3`) and major tag (`v1`)

> **⚠️ Important:** The release script only validates version format and ordering. **You are responsible for:**
> - Reviewing the changes since the last release
> - Determining if the version bump is appropriate (major/minor/patch)
> - Ensuring breaking changes are properly documented
> - Verifying all actions work as expected
>
> The script is a safeguard against simple mistakes, not a substitute for careful release management.

**Manual alternative:**
   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   git tag -f v1
   git push -f origin v1
   ```

**Versioning Guidelines:**
- **Major (v2.0.0):** Breaking changes to inputs, outputs, or behavior
- **Minor (v1.1.0):** New features, backward-compatible changes
- **Patch (v1.0.1):** Bug fixes, documentation updates

<!-- ## Changelog

Please see the [CHANGELOG.md](CHANGELOG.md) for details on individual releases. -->
