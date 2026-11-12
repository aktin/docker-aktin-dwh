 # docker-aktin-dwh

[![CI](https://github.com/aktin/docker-aktin-dwh/actions/workflows/ci.yml/badge.svg)](https://github.com/aktin/docker-aktin-dwh/actions/workflows/ci.yml)
[![CodeQL](https://github.com/aktin/docker-aktin-dwh/actions/workflows/codeql.yml/badge.svg)](https://github.com/aktin/docker-aktin-dwh/actions/workflows/codeql.yml)
[![OpenSSF Scorecard](https://api.securityscorecards.dev/projects/github.com/aktin/docker-aktin-dwh/badge)](https://securityscorecards.dev/viewer/?uri=github.com/aktin/docker-aktin-dwh)
[![License](https://img.shields.io/badge/license-AGPL--3.0-blue.svg)](./LICENSE)
[![Release](https://img.shields.io/github/v/release/aktin/docker-aktin-dwh)](https://github.com/aktin/docker-aktin-dwh/releases)

A containerized deployment of the AKTIN emergency department system using Docker Compose, consisting of:
* PostgreSQL database with i2b2/AKTIN schema
* WildFly application server
* Apache2 reverse proxy with i2b2 webclient


## Installation for Users

1. Download the [compose file](https://github.com/aktin/docker-aktin-dwh/releases/latest/download/compose.yml):
```bash
curl -LO https://github.com/aktin/docker-aktin-dwh/releases/latest/download/compose.yml
```

2. In the folder of the `compose.yml` script create a secret file with a strong password:
```bash
echo 'mysecretpassword' > secret.txt
```

3. Start the containers:
```bash
docker compose up -d
```

The system will be available at `http://localhost` once all containers have started. The AKTIN I2B2 can be reached at  `http://localhost/webclient` and the DWH manager at `http://localhost/aktin/admin`. For [bind mounts](https://docs.docker.com/engine/storage/bind-mounts/), the property files must be copied manually into the `aktin_config` folder. See [this issue]([https://github.com/aktin/docker-aktin-dwh/issues/6](https://github.com/aktin/docker-aktin-dwh/issues/10)) for details.

### Running Multiple AKTIN Instances on the same Server

To run multiple AKTIN instances on the same server, place instances of `compose.yml` in separate folders and assign unique ports per instance (`HTTP_PORT`). Docker Compose will automatically use the folder name as the project name, isolating container names, networks, and volumes. You can configure the individual instances using `.env` files:

`/opt/docker-deploy/aktin1/.env`:
```bash
HTTP_PORT=80
```

`/opt/docker-deploy/aktin2/.env`:
```bash
HTTP_PORT=81
```

Start each instance with:

```bash
# Instance 1
cd /opt/docker-deploy/aktin1
docker compose up -d

# Instance 2
cd /opt/docker-deploy/aktin2
docker compose up -d
```

### Verification of Container Signatures
All our Docker images are cryptographically signed using [Cosign](https://docs.sigstore.dev/cosign/signing/overview/)  and come with attached SBOMs (CycloneDX) and build provenance attestations (SLSA). You can check that what you run matches what we built:

#### Prerequisites
Check cosign installation. If needed, install it following [this instruction](https://docs.sigstore.dev/cosign/system_config/installation/).
```bash
cosign version

# Example output:
# GitVersion:    v2.5.3
```

#### 1. Get the Image Digest
Pull the image first:
```bash
docker pull ghcr.io/aktin/notaufnahme-dwh-<service>:<tag>

# Example command:
# docker pull ghcr.io/aktin/notaufnahme-dwh-database:1.6rc1-2-docker3
```

Inspect to find the exact digest:
```bash
docker inspect --format='{{index .RepoDigests 0}}' ghcr.io/aktin/notaufnahme-dwh-<service>:<tag>

# Example command:
# docker inspect --format='{{index .RepoDigests 0}}' ghcr.io/aktin/notaufnahme-dwh-database:1.6rc1-2-docker3

# Example output:
# ghcr.io/aktin/notaufnahme-dwh-database@sha256:3568fccb80c6f3512eb865d072ed76df7ebe35a2f6784eaad737e8b6e6e3363d
```

#### 2. Verify Image Signature
Check that the image was built by our GitHub Actions workflow and signed via Sigstore. If valid, you’ll see output confirming the signature and the trusted GitHub Repo. For more information, refer to the [OIDC Cheat Sheet](https://docs.sigstore.dev/quickstart/verification-cheat-sheet/) and the [official Documentation](https://docs.sigstore.dev/cosign/verifying/verify/). Alternatively, you can verify the digest online using the [Rekor Web UI](https://search.sigstore.dev/).
```bash
cosign verify \
--certificate-identity-regexp "^https://github\.com/aktin/docker-aktin-dwh/\.github/workflows/.*" \
--certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
ghcr.io/aktin/notaufnahme-dwh-<service>@<digest>

# Example command:
# cosign verify \
# --certificate-identity-regexp "^https://github\.com/aktin/docker-aktin-dwh/\.github/workflows/.*" \
# --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
# ghcr.io/aktin/notaufnahme-dwh-database@sha256:3568fccb80c6f3512eb865d072ed76df7ebe35a2f6784eaad737e8b6e6e3363d

# Example output:
# Verification for ghcr.io/aktin/notaufnahme-dwh-database@sha256:3568fccb80c6f3512eb865d072ed76df7ebe35a2f6784eaad737e8b6e6e3363d --
# The following checks were performed on each of these signatures:
#   - The cosign claims were validated
#   - Existence of the claims in the transparency log was verified offline
#   - The code-signing certificate was verified using trusted certificate authority certificates
```

#### 3. Inspect SBOM
Each image has an attached Software Bill of Materials. The following command prints the SBOM in JSON. This prints the CycloneDX SBOM in JSON. You can then parse it with SBOM tooling or import it into vulnerability scanners.
```bash
cosign verify-attestation \
--type cyclonedx \
--certificate-identity-regexp "^https://github\.com/aktin/docker-aktin-dwh/\.github/workflows/.*" \
--certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
ghcr.io/aktin/notaufnahme-dwh-<service>@<digest>

# Example command:
# cosign verify-attestation \
# --type cyclonedx \
# --certificate-identity-regexp "^https://github\.com/aktin/docker-aktin-dwh/\.github/workflows/.*" \
# --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
# ghcr.io/aktin/notaufnahme-dwh-database@sha256:3568fccb80c6f3512eb865d072ed76df7ebe35a2f6784eaad737e8b6e6e3363d

# Example output:
# {"payloadType":"application/vnd.in-toto+json","payload":"eyJfdHlwZSI...","signatures":[{"keyid":"","sig":"MEYCIQC..."}]}
```

#### 4. Verify Build Provenance
Build provenance attestation proves the image was built from scratch in GitHub. The result will show the Git commit and build metadata. You can then trace the build back to our public repository.
```bash
cosign verify-attestation \
--type slsaprovenance1 \
--certificate-identity-regexp "^https://github\.com/aktin/docker-aktin-dwh/\.github/workflows/.*" \
--certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
ghcr.io/aktin/notaufnahme-dwh-<service>@<digest>

# Example command:
# cosign verify-attestation \
# --type slsaprovenance1 \
# --certificate-identity-regexp "^https://github\.com/aktin/docker-aktin-dwh/\.github/workflows/.*" \
# --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
# ghcr.io/aktin/notaufnahme-dwh-database@sha256:3568fccb80c6f3512eb865d072ed76df7ebe35a2f6784eaad737e8b6e6e3363d

# Example output:
# {"payloadType":"application/vnd.in-toto+json","payload":"eyJfdHlwZSI...","signatures":[{"keyid":"","sig":"MEUCIQC..."}]}
```

#### Attention
The SBOM and build provenance are published as in-toto attestations wrapped in DSSE envelopes. The actual attestation content is base64-encoded in the `payload` field of the JSON output. You can download the attestations directly from the OCI registry and decode the embedded payload using the following command. The resulting file will contain both the SBOM and the SLSA provenance:
```bash
cosign download attestation ghcr.io/aktin/notaufnahme-dwh-<service>@<digest> | jq -r '.payload' | base64 -d | jq > output.json

# Example command:
# cosign download attestation ghcr.io/aktin/notaufnahme-dwh-database@sha256:3568fccb80c6f3512eb865d072ed76df7ebe35a2f6784eaad737e8b6e6e3363d | jq -r '.payload' | base64 -d | jq > output.json
```

## For Developers
If you want to build the containers yourself or contribute to development:

1. Clone this repository:
```bash
git clone https://github.com/aktin/docker-aktin-dwh.git
cd docker-aktin-dwh 
```

2. Run the build script:
```bash
./src/build.sh
```

The build script accepts the following arguments:

* `--cleanup`: Remove build files and downloads after image creation
* `--force-rebuild`: Force a complete image recreation
* `--use-main-branch`: Use current version from main branch instead of release versions
* `--create-latest`: Create additional containers tagged as 'latest'

3. Run the container locally after the build finished using:
```bash
cd build/
docker compose -f compose.dev.yml up -d 
```

The WildFly Docker container can run in development mode using the `DEV_MODE` environment variable. When set, the WildFly Docker will use a customized configuration file with logging of CDA imports and rscript executions.

When `DEV_MODE=true`, the `BROKER_API_KEY` environment variable is required and must be set in a `.env` file next to `compose.dev.yml`:
```bash
echo "BROKER_API_KEY=<your-api-key>" > build/.env
```

## Commits and releases

Commits follow [Conventional Commits](https://www.conventionalcommits.org), enforced by the commit-msg hook:

```
<type>(<optional scope>): <subject>
```

Allowed types are `feat fix docs style refactor perf test chore`. The subject starts lowercase, has no trailing period, and every line of the message stays at most 100 characters. Pull requests into `dev` are squash merged, so one conventional subject per PR lands on `dev`. `dev` is merged into `main` with a merge commit.

A release is a tag `v*` on `main`. The release workflow builds, signs and attests the images, writes the release notes from the commit history with git-cliff and attaches the generated `compose.yml` to the GitHub Release. The same file is committed to the branch `generated`, one commit per release, so its [history](https://github.com/aktin/docker-aktin-dwh/commits/generated/compose.yml) shows what changed between releases.

## Checks and gates

Three layers. Each layer trusts the one before it a little less. The first layer, the git hooks on your machine, is described here. The checks on pull requests, the workflows, Dependabot and the rules on `main`, `dev` and release tags are described in [.github/workflows/README.md](.github/workflows/README.md).

### On your machine

> [!CAUTION]
> Run `lefthook install` once after cloning, before your first commit. Without it no git hook runs on your machine.

You need the [lefthook](https://lefthook.dev) binary for the git hooks (`apt install lefthook`, `brew install lefthook`, or a release download) plus `python3`, `gitleaks`, `actionlint`, `hadolint` and `shellcheck`. All hooks come from aktin-github-scripts. A missing tool fails the commit, actionlint, hadolint and shellcheck are only called when a workflow file, Dockerfile or shell script is staged.

| When       | What runs                                                                                                                                                 | Blocks     |
|------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------|------------|
| pre-commit | gitleaks scans for secrets, actionlint, hadolint and shellcheck lint the staged workflow files, Dockerfiles and shell scripts, the shared scripts reject data files, large files and oversized commits | the commit |
| commit-msg | Conventional Commit header check                                                                                                                          | the commit |

The shared data file guard allows `src/resources/database/` in this repository because the schema and synthetic fixture SQL live there. Hooks can be skipped with `--no-verify`, so nothing here is a guarantee. They exist for fast feedback.

## Services

### PostgreSQL Database (database)

* Image: `notaufnahme-dwh-database`
* Provides preconfigured database environment for i2b2 and AKTIN
* Volume mounted at `/var/lib/postgresql/data`

### WildFly Application Server (wildfly)

* Image: `notaufnahme-dwh-wildfly`
* Java application server with i2b2 and AKTIN components
* Includes Python and R data processing capabilities
* Volumes mounted at `/etc/aktin` and `/var/lib/aktin`

### Apache Web Server (httpd)

* Image: `notaufnahme-dwh-httpd`
* Provides i2b2 web interface and reverse proxy configuration
* Default port: **80** (configurable via `HTTP_PORT` environment variable)

## Environment Variables
These variables can be defined in a `.env` file and are used throughout `compose.yml` to configure the system:
- `HTTP_PORT`: Exposed port for the Apache HTTPD server (default: `80`)
- `DB_HOST`: Hostname of the database container (default: `database`)
- `DB_PORT`: Port to reach PostgreSQL (default: `5432`)
- `DEV_MODE`: Enables WildFly and Database dev mode (default: `false`). WildFly is restarted automatically when Compose restarts or recreates the database service as part of `docker compose up -d` or `docker compose restart database`.  This does not happen when only the database is targeted, e.g. `docker compose up -d --force-recreate database`, or when the database container crashes and is restarted by the restart policy. In these cases WildFly drops the stale connections after a short time, or you can run `docker compose restart wildfly`.
- `BROKER_API_KEY`: API key for the AKTIN broker; required when `DEV_MODE=true`
