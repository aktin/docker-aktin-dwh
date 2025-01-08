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
The system will be available at `http://localhost` once all containers are healthy.


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
* Exposed on port 80
