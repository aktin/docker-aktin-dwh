# docker-aktin-dwh

A containerized deployment of the AKTIN emergency department system using Docker Compose, consisting of:
* PostgreSQL database with i2b2/AKTIN schema
* WildFly application server
* Apache2 reverse proxy with i2b2 webclient

## Quick Start

1. Clone this repository 
2. Run the build script:
```
./src/build.sh
```
3. Start the containers:
```
cd build/
docker compose up -d
```

## Build Options
The build.sh script accepts the following arguments:

* `--cleanup`: Remove build files and downloads after image creation
* `--force-rebuild`: Force a complete image recreation
* `--use-main-branch`: Use current version from main branch instead of release versions

## Services

### PostgreSQL Database (database)

* Image: `notaufnahme-dwh-database`
* Provides preconfigured database environment for i2b2 and AKTIN
* Volume mounted at /var/lib/postgresql/data

### WildFly Application Server (wildfly)

* Image: `notaufnahme-dwh-wildfly`
* Java application server with i2b2 and AKTIN components
* Includes Python and R data processing capabilities
* Volumes mounted at /etc/aktin and /var/lib/aktin

### Apache Web Server (httpd)

* Image: `notaufnahme-dwh-httpd`
* Provides i2b2 web interface and reverse proxy configuration
* Exposed on port 80
