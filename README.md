# github-actions

Collection of GitHub actions for ecobee. While the current examples are all composite run types, any github action style is welcome here!

| Action                                                                 |
| ---------------------------------------------------------------------- |
| [`ecobee/github-actions/go_build_artifact@main`](../go_build_artifact) |
| [`ecobee/github-actions/go_test_and_lint@main`](../go_test_and_lint)   |
| [`ecobee/github-actions/push_docker_gcr@main`](../push_docker_gcr)     |

## Usage

See individual action directory for details on usage and examples.

- [Go Build artifact](../go_build_artifact) - builds golang binary and outputs build tag
- [Go Test and Lint](../go_test_and_lint) - runs golang tests, and lints with golangci-lint
- [Push Docker GCR](../push_docker_gcr) - creates docker file from expected artifact, using supplied build tag

<!-- ## Changelog

Please see the [CHANGELOG.md](CHANGELOG.md) for details on individual releases. -->
