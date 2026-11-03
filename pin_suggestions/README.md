The `pin_suggestions` GitHub action suggests SHA pins for GitHub Actions on pull requests.

SonarQube and Wiz flag workflow lines like `uses: actions/setup-go@v6` because a tag can be moved to different code. This action comments on each such line your pull request adds with the pinned form, for example `uses: actions/setup-go@<sha> # v6.1.0`, which runs exactly what `@v6` runs today. Select "Add suggestion to batch" on each comment, then "Commit suggestions". It all happens in the browser, so nothing needs installing.

It's advisory: it never blocks your pull request and never commits for you. Internal `ecobee/` actions are left alone. Lines it can't pin get an error comment with the reason instead of a suggestion, for example a reference that doesn't exist or a SHA that isn't any release of that action.

## Usage

Add this file to your repository as `.github/workflows/pin-suggestions.yml`:

```yml
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
    runs-on: ubuntu-24.04
    steps:
      - uses: ecobee/github-actions/pin_suggestions@v1
```

Keep it as its own job. The action checks out your repository itself, so adding it to a job that already checked out with custom settings would reset that workspace. Don't make it a required check; leaving it optional is what keeps it from blocking anyone.

## When it posts nothing

The action only comments on `pull_request` events opened from a branch in the same repository. Anywhere else it ends early with a notice in the job log explaining why, and the check still passes.

- Pull requests from forks: GitHub gives them a read-only token, which can't post review comments.
- Other events such as `push`, `pull_request_target` or `merge_group`: suggestions need a pull request diff to attach to. `pull_request_target` is also unsafe here, since it would run with a write token against untrusted code.

If you see that notice on a pull request from your own repository, check that the workflow triggers on `pull_request` as shown above. The check can still go red if something outside pinact fails, such as checkout or a runner timeout; because it isn't required, that never blocks a merge.

## Keeping pins current

Let Dependabot bump pins. It updates the SHA and version comment together. Group updates into one weekly pull request, and wait seven days after a release so a hijacked release has time to be caught. Don't ignore minor or patch updates, because pinned references would then never move.

```yml
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

## Maintainers

The pinning policy is [`pinact.yaml`](./pinact.yaml) and is specified by [`tests/pin_suggestions/test.sh`](../tests/pin_suggestions/test.sh). Run the specs with the pinact version named in the spec on your `PATH`:

```sh
GITHUB_TOKEN=$(gh auth token) tests/pin_suggestions/test.sh
```

When bumping pinact-action, update `PINACT_VERSION` in the spec and `PINACT_SHA256` in the test workflow to match the pinact it bundles.
