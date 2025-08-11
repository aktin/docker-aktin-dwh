# Running GitHub Actions Locally with `act`

This repo uses [`act`](https://github.com/nektos/act) to run GitHub Actions workflows locally for testing CI/CD pipelines. `act` lets you run GitHub Actions using Docker simulating the GitHub Actions environment.

## Prerequisites

- Docker installed and running
- `act` installed ([install guide](https://nektosact.com/installation/index.html))
- A `.secrets` file in the project root with the following format:

```
DEV_API_KEY=your_api_key_here
```

## How to Run
These test workflows are triggered manually (`workflow_dispatch`) and do **not** push or publish anything when tested with `act`.

### Arguments:
- `-j`: Job name to run
- `--secret-file`: Injects secrets required by the workflow

### Run the Digest Update Check Workflow

This workflow simulates checking for a base container image update (e.g. `postgres`) based on the version in `src/resources/versions`.

```bash
act -j test-postgresql
```

### Run the Docker Build & Release Workflow

This workflow builds the Docker images and simulates pushing them and preparing release artifacts.

```bash
act -j test-release --secret-file .secrets
```
