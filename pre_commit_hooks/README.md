
## pre-commit hooks

This repo is also hosting some pre-commit-hooks. The hooks are located in the
`pre_commit_hooks` directory (e.g. `remove_crlf.py`). For this to be installable
by `pre-commit` tool, we needed to add the following files: `setup.py` and
`.pre-commit-hooks.yaml`.

Here is an example how to add the `remove_crlf` to a `.pre-commit-config.yaml`
file:

```
  - repo: git@github.com:ecobee/github-actions
    rev: ec4eebb331c8392ba7f180c403b6ae2b9c166e99
    hooks:
      - id: remove-crlf
        exclude: ".*.patch$"
```
