The `push_docker_gcr` GitHub action will build a golang image using the repo's Makefile (by default). You can opt to specify an alternative build command. The artifact is tagged with a time/datestamp (`%Y-%m-%dT%H:%M:%S`), and the sha of the commit. It will also create a copy of the built artifact with the build-tag appended (for later upload if desired).

## Usage

This requires that your build process outputs an artifact whose file name matches your `service`

```yml
- uses: ecobee/github-actions/push_docker_gcr@main
  with:
    # The command used to build your artifact
    # Required: false
    build-command: 'make artifact-local'

    # The GCP project to be used
    # Required: true
    project: ''

    # The name of the service (repo name) to be published
    # Required: true
    service: ''
```

## Outputs

- `build-tag` - action will output a build-tag generated when creating the artifact

## Future options

Things we could do in the future include, but are not limited to:

- specify what tagging schema to use (default `{timestamp}-{github.sha}`)
