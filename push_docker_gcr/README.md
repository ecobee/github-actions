The `push_docker_gcr` GitHub action will build a docker container based on the repo's Dockerfile, and then push this to gcr.io. The image is tagged with a whatever `build-tag` you input. Another `:latest` tag is also pushed.

## Usage

This requires that you have previously run the `google-github-actions/setup-gcloud` action first. This action will then authorize docker, in order to push to `gcr.io`

```yml
- uses: ecobee/github-actions/go_build_docker_gcr@main
  with:
    # The build tag to use for the resultant docker image
    # Required: true
    build-tag: ''

    # The GCP project to be used
    # Required: true
    project: ''

    # The name of the service (repo name) to be published
    # Required: true
    service: ''
```

## Future options

Things we could do in the future include, but are not limited to:

- specify which repo to upload to (default `gcr.io`)
