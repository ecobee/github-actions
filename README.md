# github-actions

Collection of GitHub actions for ecobee. While the current examples are all composite run types, any github action style is welcome here!

| Action                                                                 |
| ---------------------------------------------------------------------- |
| [`ecobee/github-actions/go_build_artifact@v1`](../go_build_artifact) |
| [`ecobee/github-actions/go_test_and_lint@v1`](../go_test_and_lint)   |
| [`ecobee/github-actions/push_docker_gcr@v1`](../push_docker_gcr)     |
| [`ecobee/github-actions/publish_dx_dora_metrics@v1`](../publish_dx_dora_metrics) |

## Usage

See individual action directory for details on usage and examples.

- [Go Build artifact](../go_build_artifact) - builds golang binary and outputs build tag
- [Go Test and Lint](../go_test_and_lint) - runs golang tests, and lints with golangci-lint
- [Push Docker GCR](../push_docker_gcr) - creates docker file from repo's Dockerfile, pushed using supplied build tag
- [Publish DX DORA Metrics](../publish_dx_dora_metrics) - publishes deployment metrics to DX for DORA tracking

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
