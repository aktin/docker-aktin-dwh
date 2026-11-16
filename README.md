 # docker-aktin-dwh

[![Verify](https://github.com/aktin/docker-aktin-dwh/actions/workflows/verify.yml/badge.svg)](https://github.com/aktin/docker-aktin-dwh/actions/workflows/verify.yml)
[![CodeQL](https://github.com/aktin/docker-aktin-dwh/actions/workflows/scan-codeql.yml/badge.svg)](https://github.com/aktin/docker-aktin-dwh/actions/workflows/scan-codeql.yml)
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

2. In the folder of the `compose.yml` file create a secret file with a strong password:
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

### Verification of Container Images
Every Docker image is published with a build provenance attestation (SLSA) and an SBOM attestation (CycloneDX). Both are signed and stored at GitHub. You can check that what you run matches what we built:

#### Prerequisites
Check the GitHub CLI installation. If needed, install it following [this instruction](https://cli.github.com/).
```bash
gh --version

# Example output:
# gh version 2.102.1 (2026-10-20)
# https://github.com/cli/cli/releases/tag/v2.102.1
```

Log in with your GitHub account. The command guides you through the login:
```bash
gh auth login
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

#### 2. Verify Build Provenance
The build provenance attestation proves that the image was built on GitHub from this repository. `--repo` names the repository that built the image. `--signer-repo` names the repository of the shared AKTIN workflow that created the attestation. For more information, refer to the [GitHub CLI manual](https://cli.github.com/manual/gh_attestation_verify).
```bash
gh attestation verify oci://ghcr.io/aktin/notaufnahme-dwh-<service>@<digest> \
--repo aktin/docker-aktin-dwh \
--signer-repo aktin/aktin-github-scripts

# Example command:
# gh attestation verify oci://ghcr.io/aktin/notaufnahme-dwh-database@sha256:3568fccb80c6f3512eb865d072ed76df7ebe35a2f6784eaad737e8b6e6e3363d \
# --repo aktin/docker-aktin-dwh \
# --signer-repo aktin/aktin-github-scripts

# Example output (shortened):
# ✓ Verification succeeded!
#
# - Attestation #1
#   - Build repo:..... aktin/docker-aktin-dwh
#   - Build workflow:. .github/workflows/rebuild-on-base-update.yml@refs/heads/main
#   - Signer repo:.... aktin/aktin-github-scripts
#   - Signer workflow: .github/workflows/build-publish-image.yml@refs/heads/main
```

`Build workflow` names `release.yml` for an image of a release. It names `rebuild-on-base-update.yml` for an image that was rebuilt because its base image changed.

#### 3. Inspect SBOM
Each image has a Software Bill of Materials as a second attestation. The following command verifies it and writes the CycloneDX SBOM in JSON to the file `sbom.cdx.json`. You can then parse it with SBOM tooling or import it into vulnerability scanners.
```bash
gh attestation verify oci://ghcr.io/aktin/notaufnahme-dwh-<service>@<digest> \
--repo aktin/docker-aktin-dwh \
--signer-repo aktin/aktin-github-scripts \
--predicate-type https://cyclonedx.org/bom \
--format json \
--jq '.[].verificationResult.statement.predicate' > sbom.cdx.json

# Example command:
# gh attestation verify oci://ghcr.io/aktin/notaufnahme-dwh-database@sha256:3568fccb80c6f3512eb865d072ed76df7ebe35a2f6784eaad737e8b6e6e3363d \
# --repo aktin/docker-aktin-dwh \
# --signer-repo aktin/aktin-github-scripts \
# --predicate-type https://cyclonedx.org/bom \
# --format json \
# --jq '.[].verificationResult.statement.predicate' > sbom.cdx.json

# Example content of sbom.cdx.json (shortened):
# {"bomFormat":"CycloneDX","components":[...],...}
```

## For Developers
If you want to build the containers yourself or contribute to development:

1. Clone this repository:
```bash
git clone https://github.com/aktin/docker-aktin-dwh.git
cd docker-aktin-dwh 
```

2. Run the build script. It needs `curl`, `unzip`, `docker`, `java` and `mvn`. It first stops and removes running containers and existing images of the services it builds:
```bash
./src/build.sh
```

The build script accepts the following arguments:

* `--cleanup`: Remove build files and downloads after image creation
* `--force-rebuild`: Build the images without the Docker build cache
* `--use-main-branch`: Download the main branch of the AKTIN packages `debian-i2b2-pkg` and `debian-dwh-pkg` instead of the versions set in `src/resources/versions`
* `--create-latest`: Also tag the built images as `latest`
* `--service <name>`: Build only this image (`database`, `wildfly` or `httpd`), repeatable. Without it all three are built
* `--help`: Print the list of arguments

```bash
./src/build.sh --service <name>

# Example command:
# ./src/build.sh --service database --service httpd
```

3. Go to the build folder. Create the secret file and the `.env` file with the API key of the AKTIN test broker:
```bash
cd src/build/
echo 'mysecretpassword' > secret.txt
echo "BROKER_API_KEY=<your-api-key>" > .env

# Example command:
# echo "BROKER_API_KEY=abc123" > .env
```

4. Start the containers:
```bash
docker compose -f compose.dev.yml up -d
```

`compose.dev.yml` starts WildFly in development mode (`DEV_MODE=true`). In development mode WildFly uses a customized configuration file with logging of CDA imports and rscript executions and needs `BROKER_API_KEY`. The database starts in development mode only when `.env` holds `DEV_MODE=true`. It then uses a separate test cluster with test patients and leaves the data volume untouched. The test cluster lives inside the container, not in a volume, and is lost when the container is recreated. In development mode WildFly connects to the AKTIN test broker, and `compose.dev.yml` mounts `debug/cda` and `debug/report-temp` from the build folder into WildFly.

## Commits and releases

Commits follow [Conventional Commits](https://www.conventionalcommits.org), enforced by the commit-msg hook:

```
<type>(<optional scope>): <subject>
```

Allowed types are `feat fix docs style refactor perf test chore`. The subject starts lowercase, has no trailing period, and every line of the message stays at most 100 characters. Pull requests into `dev` are squash merged, so one conventional subject per PR lands on `dev`. `dev` is merged into `main` with a merge commit.

A release is a tag `v*` on `main`. The tag starts the release workflow, which is described in [.github/workflows/README.md](.github/workflows/README.md#workflows). It publishes the three images and a GitHub Release with the release notes, the generated `compose.yml` and one SBOM file per image. The same `compose.yml` is committed to the branch `generated`, one commit per release that changes it, so its [history](https://github.com/aktin/docker-aktin-dwh/commits/generated/compose.yml) shows what changed between releases.

The tags of the images do not come from the git tag. `src/build.sh` reads them from `src/resources/versions`: the value of `DWH_GITHUB_TAG`, then `-docker`, then the revision of the image, for example `1.7rc1-1-docker1`.

## Checks and gates

Three layers. Each layer trusts the one before it a little less. The first layer, the git hooks on your machine, is described here. The checks on pull requests, the workflows, Dependabot and the rules on `main`, `dev` and release tags are described in [.github/workflows/README.md](.github/workflows/README.md).

### On your machine

> [!CAUTION]
> Run `lefthook install` once after cloning, before your first commit. Without it no git hook runs on your machine.

You need the [lefthook](https://lefthook.dev) binary in version 2.0.5 or newer for the git hooks (`apt install lefthook`, `brew install lefthook`, or a release download) plus `python3`, `gitleaks`, `actionlint`, `hadolint` and `shellcheck`. All hooks come from [aktin-github-scripts](https://github.com/aktin/aktin-github-scripts#git-hooks) through `lefthook.yml`. Its README lists every hook and its limits. A missing tool fails the commit, actionlint, hadolint and shellcheck are only called when a workflow file, Dockerfile or shell script is staged.

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
- `TZ`: Time zone of the WildFly container (default: `Europe/Berlin`)
- `LANG` and `LC_ALL`: Locale of the WildFly container (default: `de_DE.UTF-8`). A value that is set in your shell wins over the `.env` file, and most shells set `LANG`
- `DATABASE_CONTAINER_VERSION`, `WILDFLY_CONTAINER_VERSION` and `HTTPD_CONTAINER_VERSION`: Tag of the database, WildFly and httpd image (default: the tag of the release the `compose.yml` belongs to)
- `DEV_MODE`: Enables WildFly and Database dev mode (default: `false`). Use it with `compose.dev.yml` only, see [For Developers](#for-developers)
- `BROKER_API_KEY`: API key for the AKTIN test broker. Only `compose.dev.yml` reads it. Required when WildFly runs with `DEV_MODE=true`

WildFly is restarted automatically when Compose restarts or recreates the database service as part of `docker compose up -d` or `docker compose restart database`. This does not happen when only the database is targeted, e.g. `docker compose up -d --force-recreate database`, or when the database container crashes and is restarted by the restart policy. In these cases WildFly drops the stale connections after a short time, or you can run `docker compose restart wildfly`.
