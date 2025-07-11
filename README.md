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
The system will be available at `http://localhost` once all containers have started. For [bind mounts](https://docs.docker.com/engine/storage/bind-mounts/), the property files must be copied manually into the `aktin_config` folder. See [this issue]([https://github.com/aktin/docker-aktin-dwh/issues/6](https://github.com/aktin/docker-aktin-dwh/issues/10)) for details.

### Verification of container signatures
All our Docker images are signed using [Cosign](https://docs.sigstore.dev/cosign/signing/overview/) with keyless signing. You can check that what you run matches what we built:

1. Check cosign installation
```bash
cosign version

# Install if needed:
# macOS: brew install cosign
# Linux: curl -sSL https://raw.githubusercontent.com/sigstore/cosign/main/install.sh | sh
```

2. Get the image digest 

Pull the image first:
```bash
docker pull ghcr.io/aktin/notaufnahme-dwh-database:latest
```

Inspect to find the exact digest:
```bash
docker inspect --format='{{index .RepoDigests 0}}' ghcr.io/aktin/notaufnahme-dwh-database:latest

# Example output:
# ghcr.io/aktin/notaufnahme-dwh-database@sha256:abc123...
```

3. Verify the signature

Replace `<digest>` with your actual digest:
```bash
cosign verify ghcr.io/aktin/notaufnahme-dwh-database@<digest> --certificate-identity="repo:aktin/docker-aktin-dwh" --certificate-oidc-issuer="https://token.actions.githubusercontent.com"
```

If valid, you’ll see output confirming the signature and the trusted GitHub repo. For more information, refer to the [official Documentation](https://docs.sigstore.dev/cosign/verifying/verify/).

### Running Multiple AKTIN Instances on the Same Server

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
