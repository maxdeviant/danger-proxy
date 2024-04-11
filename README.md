# danger-proxy

A proxy for using [Danger](https://danger.systems/js/) on public repos.

## Setup

You will need to provide the following environment variables:

```
SECRET_KEY_BASE=<openssl rand -base64 64>
GITHUB_API_TOKEN=<GitHub API token>
ALLOWED_REPOS=owner/repo
```
