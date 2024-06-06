# Releasing this library

## With Github Workflows

Create an annotated tag following a Semantic Versioning.
the release.yml uses a github action that will create a 
pre-release release for alphas and betas and "release"
releases for Semantic Versioning compliant tags. This is
explained with detail [here](https://github.com/ghalactic/github-release-from-tag?tab=readme-ov-file#example-release-stabilities).


**Example:**
Creating `0.1.0-beta.6`

Create an annotated tag
`git tag --annotate --cleanup=whitespace --edit --message "" 0.1.0-beta.6`

This will prompt you for a message.
The message content follows the logic [documented here](https://github.com/ghalactic/github-release-from-tag?tab=readme-ov-file#release-name-and-body).



