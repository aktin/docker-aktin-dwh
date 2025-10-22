# docker-aktin-dwh

A containerized deployment of the AKTIN emergency department system using Docker Compose, consisting of:
* PostgreSQL database with i2b2/AKTIN schema
* WildFly application server
* Apache2 reverse proxy with i2b2 webclient


## Installation for Users

1. Download the compose file:
```bash
curl -LO https://github.com/aktin/docker-aktin-dwh/releases/latest/download/compose.yml
```
2. In the folder of the `compose.yml` script create a secret file with a strong password:
```bash
echo 'mysecretpassword' > secret.txt
```
3. Start the containers:
```
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
docker pull ghcr.io/aktin/notaufnahme-dwh-database:1.6rc1-2-docker3
```

Inspect to find the exact digest:
```bash
docker inspect --format='{{index .RepoDigests 0}}' ghcr.io/aktin/notaufnahme-dwh-database:1.6rc1-2-docker3

# Example output:
# ghcr.io/aktin/notaufnahme-dwh-database@sha256:dff86c69b2042df7259d778ab76799b95789e4cebd1a81fda1fd47444b724ecd
```

#### 2. Verify Image Signature
Check that the image was built by our GitHub Actions workflow and signed via Sigstore. If valid, you’ll see output confirming the signature and the trusted GitHub Repo. For more information, refer to the [OIDC Cheat Sheet](https://docs.sigstore.dev/quickstart/verification-cheat-sheet/) and the [official Documentation](https://docs.sigstore.dev/cosign/verifying/verify/). Alternatively, you can verify the digest online using the [Rekor Web UI](https://search.sigstore.dev/).
```bash
cosign verify \
--certificate-identity "https://github.com/aktin/docker-aktin-dwh/.github/workflows/build-deploy-docker.yml@refs/heads/main" \
--certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
ghcr.io/aktin/notaufnahme-dwh-database@sha256:dff86c69b2042df7259d778ab76799b95789e4cebd1a81fda1fd47444b724ecd
```

#### 3. Inspect SBOM
Each image has an attached Software Bill of Materials. The following command prints the SBOM in JSON. This prints the CycloneDX SBOM in JSON. You can then parse it with SBOM tooling or import it into vulnerability scanners.
```bash
cosign verify-attestation \
--type cyclonedx \
--certificate-identity "https://github.com/aktin/docker-aktin-dwh/.github/workflows/build-deploy-docker.yml@refs/heads/main" \
--certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
ghcr.io/aktin/notaufnahme-dwh-database@sha256:dff86c69b2042df7259d778ab76799b95789e4cebd1a81fda1fd47444b724ecd
```

#### 4. Verify Build Provenance
Build provenance attestation proves the image was built from scratch in GitHub. The result will show the Git commit and build metadata. You can then trace the build back to our public repository.
```bash
cosign verify-attestation \
--type https://slsa.dev/provenance/v0.2 \
--certificate-identity "https://github.com/slsa-framework/slsa-github-generator/.github/workflows/generator_container_slsa3.yml@refs/tags/v2.1.0" \
--certificate-oidc-issuer https://token.actions.githubusercontent.com \
ghcr.io/aktin/notaufnahme-dwh-database@sha256:dff86c69b2042df7259d778ab76799b95789e4cebd1a81fda1fd47444b724ecd
```

#### Attention
The SBOM and build provenance attestations are stored as in-toto DSSE envelopes, where the actual payload is base64-encoded inside a JSON wrapper. You can decode and inspect the raw payload with:
```bash
cosign verify-attestation <image>@<digest> | jq -r '.payload' | base64 -d | jq
```

## For Developers
If you want to build the containers yourself or contribute to development:

1. Clone this repository:
```bash
git clone https://github.com/aktin/docker-aktin-dwh.git
cd docker-aktin-dwh 
```

2. Set the required `DEV_API_KEY` environment variable:
```bash
export DEV_API_KEY="<your-development-api-key>"
```

Alternatively, you can create a `.env` file in the project root:
```bash
echo "DEV_API_KEY=<your-development-api-key>" > .env
source .env
```

3. Run the build script:
```bash
DEV_API_KEY="<your-development-api-key>" ./src/build.sh
```

The build script accepts the following arguments:

* `--cleanup`: Remove build files and downloads after image creation
* `--force-rebuild`: Force a complete image recreation
* `--use-main-branch`: Use current version from main branch instead of release versions
* `--create-latest`: Create additional containers tagged as 'latest'

4. Run the container locally after the build finished using:
```bash
cd build/
docker compose -f compose.dev.yml up -d 
```

The WildFly Docker container can run in development mode using the `DEV_MODE` environment variable. When set, the WildFly Docker will use a customized configuration file and mount a separate volume to `/opt/wildfly/standalone/deployments` to allow for isolated development deployments. `DEV_MODE=true` is set by default in the `compose.dev.yml`.

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
- `DEV_MODE`: Enables WildFly dev mode (default: `false`)
