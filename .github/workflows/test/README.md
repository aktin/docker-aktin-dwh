# Running GitHub Actions Locally with `act`

This repo uses [`act`](https://github.com/nektos/act) to run GitHub Actions workflows locally for testing CI/CD pipelines. `act` lets you run GitHub Actions using Docker simulating the GitHub Actions environment.

## Prerequisites

- Docker installed and running
- `act` installed ([install guide](https://nektosact.com/installation/index.html))

## How to Run
These test workflows are triggered manually (`workflow_dispatch`) and do **not** push or publish anything when tested with `act`.

### Arguments:
- `-j`: Job name to run

### Run the Digest Update Check Workflow

This workflow simulates checking for a base container image update (e.g. `postgres`) based on the version in `src/resources/versions`.

```bash
act -j test-postgresql
```

### Run the Docker Build & Release Workflow

This workflow builds the Docker images and simulates pushing them and preparing release artifacts.

```bash
act -j test-release
```

### Run the Security Scan Workflow

This workflow builds the Docker images and runs comprehensive security scans including Hadolint, Dockle, Trivy, and generates SBOMs with Syft.

```bash
# Run with results saved to ./scan-results
act -j test-scan --bind "$(pwd):/workspace"

# View results after completion
ls -la ./scan-results/
cat ./scan-results/SUMMARY.md
```

The scan results will include:
- hadolint.txt - Dockerfile linting issues
- dockle.txt - Container hardening recommendations
- trivy-vulns.txt - CVE vulnerabilities (HIGH/CRITICAL)
- trivy-config.txt - Configuration issues
- trivy-secrets.txt - Exposed secrets detection
- sbom/ - CycloneDX XML SBOMs for each image
