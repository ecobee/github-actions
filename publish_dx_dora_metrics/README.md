# Publish DX DORA Metrics

Publishes deployment metrics to DX (ecobee.getdx.net) for DORA tracking and visibility.

## Prerequisites

**Required Secret:** `DX_API_TOKEN` must be configured at the organization or repository level in GitHub Secrets.

Contact your platform team to ensure this secret is available in your repository or organization settings.

## Usage

```yaml
- name: Publish DORA metrics
  uses: ecobee/github-actions/publish_dx_dora_metrics@v1
  env:
    DX_API_TOKEN: ${{ secrets.DX_API_TOKEN }}
  with:
    repository: 'ecobee/my-service'
    environment: 'production'
    service: 'my-service'
```

> **Note:** Use `@v1` for the latest stable version, `@v1.0.0` to pin to a specific release, or `@main` for the latest (unstable) version.

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `repository` | Repository identifier (e.g., `ecobee/service-name`) | Yes | - |
| `environment` | Deployment environment (`prod`, `staging`, `test`, etc.) | Yes | - |
| `service` | Service identifier | Yes | - |
| `commit-sha` | Git commit SHA | No | `${{ github.sha }}` |
| `deployed-at` | Unix timestamp of deployment | No | Current time |

## Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `DX_API_TOKEN` | DX API token for authentication | Yes |

## Example Workflow

```yaml
name: Deploy to Production

on:
  push:
    branches:
      - main

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      # ... your deployment steps ...
      
      - name: Publish deployment metrics
        uses: ecobee/github-actions/publish_dx_dora_metrics@v1
        env:
          DX_API_TOKEN: ${{ secrets.DX_API_TOKEN }}
        with:
          repository: 'ecobee/my-service'
          environment: 'production'
          service: 'my-service'
```

## Versioning

This action follows [semantic versioning](https://semver.org/). When integrating:
- Use `@v1` to automatically get non-breaking updates (recommended)
- Use `@v1.0.0` to pin to a specific release
- Avoid `@main` in production workflows (unstable)

## Security Notes

- The `DX_API_TOKEN` is **never** passed as an action input to prevent accidental exposure in logs
- The token must be configured in GitHub Secrets (organization or repository level)
- The action will fail explicitly if the token is not available
- Never commit tokens or credentials to the repository