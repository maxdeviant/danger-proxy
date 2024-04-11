# Danger Proxy

A proxy for using [Danger](https://danger.systems/js/) on public repos.

## Raison d'être

Danger is an awesome tool for automating code review and codifying team norms.

However, setting up Danger to run on a public repository can be a bit tricky to do properly. The main issue stems from ensuring that Danger has a GitHub access token to use to interact with the GitHub API while simultaneously preventing that token from being disclosed to the world.

This turns out to be a bit of a tricky task, especially when you pull requests from forks come into play. Since GitHub Actions do not provide secrets to forks, it presents a challenge in storing the access token securely.

Danger Proxy exists to allow Danger to interface with the GitHub API in a more secure fashion.

Danger Proxy will:

- Proxy all requests to `/github/*` to the GitHub API. The provided GitHub API token will be used for authentication.
- Restrict requests to the list of repositories specified in the `ALLOWED_REPOS` environment variable.
- Restrict requests to the subset of the GitHub API that Danger requires.

## Setup

You will need to provide the following environment variables:

```
SECRET_KEY_BASE=<openssl rand -base64 64>
GITHUB_API_TOKEN=<GitHub API token>
ALLOWED_REPOS=owner/repo1,owner/repo2
```

## Deployment

Danger Proxy can be easily deployed to [Fly.io](https://fly.io/).

Just make your modifications to [`fly.toml`](./fly.toml) to suit your needs, add the environment variables mentioned in [Setup](#setup), and run `flyctl deploy`.
