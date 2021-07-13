The `go_test_and_lint` GitHub action will run golang tests, as well as golangci-lint against the repo

## Usage

```yml
- uses: ecobee/github-actions/go_test_and_lint@main
```

## Future options

Things we could do in the future include, but are not limited to:

-   specifying which linter to use
-   providing options to the linters
-   exporting test coverage to be used elsewhere
