# Publish DX DORA Metrics (Trunk-Based)

Publishes deployment metrics to DX (ecobee.getdx.net) for trunk-based development workflows where code is committed directly to the main branch and deployed.

## Prerequisites

**Required Secret:** `DX_API_TOKEN` is configured as a GitHub organizational secret.

This secret is managed centrally by the SRE team and is automatically available to all repositories in the ecobee organization.

## Usage

```yaml
- name: Publish DORA metrics
  uses: ecobee/github-actions/publish_dx_dora_metrics_trunk_based@v1
  env:
    DX_API_TOKEN: ${{ secrets.DX_API_TOKEN }}
  with:
    repository: 'ecobee/my-service'
    service: 'my-service'
    # Optional: defaults to 'production' - only needed for testing
    environment: 'staging'
    # Optional: for change lead time tracking
    commit-timestamp: ${{ github.event.head_commit.timestamp }}
```

> **Note:** Use `@v1` for the latest stable version, `@v1.0.0` to pin to a specific release, or `@main` for the latest (unstable) version.

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `repository` | Repository identifier (e.g., `ecobee/service-name`) | Yes | - |
| `environment` | Deployment environment | No | `production` |
| `service` | Service identifier | Yes | - |
| `commit-timestamp` | Commit timestamp (Unix timestamp or ISO 8601) | Yes | - |

> **Note:** `commit-timestamp` is required for change lead time tracking. Use `${{ github.event.head_commit.timestamp }}` (ISO 8601 format) - the action will automatically convert it to Unix timestamp.

## Environment Variables

| Variable | Description | Required | Source |
|----------|-------------|----------|--------|
| `DX_API_TOKEN` | DX API token for authentication | Yes | GitHub organizational secret |

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
        uses: ecobee/github-actions/publish_dx_dora_metrics_trunk_based@v1
        env:
          DX_API_TOKEN: ${{ secrets.DX_API_TOKEN }}
        with:
          repository: 'ecobee/my-service'
          service: 'my-service'
          commit-timestamp: ${{ github.event.head_commit.timestamp }}
```

## Versioning

This action follows [semantic versioning](https://semver.org/). When integrating:
- Use `@v1` to automatically get non-breaking updates (recommended)
- Use `@v1.0.0` to pin to a specific release
- Avoid `@main` in production workflows (unstable)

## Security Notes

- The `DX_API_TOKEN` is **never** passed as an action input to prevent accidental exposure in logs
- The token is configured as a GitHub organizational secret, managed centrally by the SRE team
- The action will fail explicitly if the token is not available
- Never commit tokens or credentials to the repository
