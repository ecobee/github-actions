The `go_build_docker_gcr` GitHub action will build a golang image, a docker container based on the repos Dockerfile, and then push these to gcr.io. The image is tagged with a time/datestamp (`%Y-%m-%dT%H:%M:%S`), and the sha of the commit. Another `:latest` tag is also pushed.

## Usage

This requires that you have previously run the `google-github-actions/setup-gcloud` action first. This action will then authorize docker, in order to push to `gcr.io`

```yml
- uses: ecobee/github-actions/go_build_docker_gcr@main
  with:
      # The GCP project to be used
      # Required: true
      project: ''

      # The name of the service (repo name) to be published
      # Required: true
      service: ''
```

## Outputs

-   `timestamp` - action will output a timestamp generated when tagging/pushing the docker image

## Future options

Things we could do in the future include, but are not limited to:

-   specify which repo to upload to (default `gcr.io`)
-   specify what tagging schema to use (default `{timestamp}-{github.sha}`)
