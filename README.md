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

2. Start the containers:
```
docker compose up -d
```
The system will be available at `http://localhost` once all containers are started.

To run multiple AKTIN instances on the same server, configure unique ports and project names for each instance by setting the appropriate values to `PROJECT_NAME` and `HTTP_PORT`:

```bash
# Instance 1
PROJECT_NAME=aktin1 HTTP_PORT=80 docker compose up -d

# Instance 2
PROJECT_NAME=aktin2 HTTP_PORT=81 docker compose up -d
```

Each instance will be isolated with its own network, volumes, and ports.

## For Developers
If you want to build the containers yourself or contribute to development:

1. Clone this repository:
```bash
git clone https://github.com/aktin/docker-aktin-dwh .git
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

3. Run the container locally using:
```bash
cd build/
docker compose -f compose.dev.yml up -d 
```

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
* Default port: 80 (configurable via HTTP_PORT environment variable)

## Environment Variables

* `PROJECT_NAME`: Sets the project name for the Docker Compose deployment (default: build)
* `HTTP_PORT`: Sets the exposed port for the Apache web server (default: 80)
