#!/bin/bash
#--------------------------------------
# Script Name:  build.sh
# Version:      1.1
# Author:       shuening@ukaachen.de, skurka@ukaachen.de, akombeiz@ukaachen.de
# Date:         05 Dec 24
# Purpose:      ToDo
#--------------------------------------

set -euo pipefail

CLEANUP=false
USE_MAIN=false

usage() {
  echo "Usage: $0 [--cleanup] [--use-main-branch]" >&2
  echo "  --cleanup          Optional: Remove build directory after package creation" >&2
  echo "  --use-main-branch  Optional: Download the current version from main branch instead of tagger releases" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case $1 in
    --cleanup)
      CLEANUP=true
      shift
      ;;
    --use-main-branch)
      USE_MAIN=true
      shift
      ;;
    -h|--help)
      usage
      ;;
    *)
      echo "Error: Unexpected argument '$1'" >&2
      usage
      ;;
  esac
done

# Define relevant directories as absolute paths
readonly DIR_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly DIR_DOCKER="${DIR_SRC}/docker/"
readonly DIR_BUILD="${DIR_SRC}/build/"
readonly DIR_RESOURCES="${DIR_SRC}/resources"
readonly DIR_DOWNLOADS="${DIR_SRC}/downloads"

load_docker_environment_variables() {
  if [ -f "${DIR_SRC}/.env" ]; then
    set -a
    . "${DIR_SRC}/.env"
    set +a
  else
    echo "Error: .env file not found in ${DIR_SRC}" >&2
    exit 1
  fi
  if [[ ! -d "${DIR_BUILD}" ]]; then
    mkdir -p "${DIR_BUILD}"
  fi
  if [[ ! -d "${DIR_DOWNLOADS}" ]]; then
    mkdir -p "${DIR_DOWNLOADS}"
  fi
}

download_artifacts() {
  local -r base_url="https://github.com/aktin"
  local -r api_url="https://api.github.com/repos/aktin"
  local use_main=${1:-false}
  echo "Downloading required artifacts..."
  mkdir -p "${DIR_DOWNLOADS}"

  download_package() {
    local pkg_name="$1"
    local version="$2"
    local zip_file="${DIR_DOWNLOADS}/${pkg_name}.zip"
    # Use cached version if available
    [[ -f "${zip_file}" ]] && { echo "Using cached ${pkg_name}.zip"; return 0; }
    # Download the latest version instead
    if [ "$use_main" = true ]; then
      echo "Downloading ${pkg_name} main branch..."
      curl -L -o "${zip_file}" "${base_url}/debian-${pkg_name}-pkg/archive/refs/heads/main.zip"
      return 0
    fi
    # Verify tag exists before attempting download
    local http_code
    http_code=$(curl -s -o /dev/null -w "%{http_code}" "${api_url}/debian-${pkg_name}-pkg/git/refs/tags/v${version}")
    if [[ "${http_code}" -ne 200 ]]; then
      echo "Error: ${pkg_name} version ${version} does not exist" >&2
      return 1
    fi
    # Download package from GitHub releases
    echo "Downloading ${pkg_name} package version ${version}..."
    curl -L -o "${zip_file}" "${base_url}/debian-${pkg_name}-pkg/archive/refs/tags/v${version}.zip"
  }
  download_package "i2b2" "${I2B2_DEBIAN_RELEASE}"
  download_package "dwh" "${DWH_DEBIAN_RELEASE}"
}

extract_artifacts() {
  echo "Extracting artifacts..."

  extract_src() {
     local pkg_name="$1"
     local version="$2"
     local zip_file="${DIR_DOWNLOADS}/${pkg_name}.zip"
     local src_path="debian-${pkg_name}-pkg-${version}/src"
     local target_dir="${DIR_DOWNLOADS}/${pkg_name}"

     echo "Extracting ${pkg_name} source files..."
     rm -rf "${target_dir}"
     mkdir -p "${target_dir}"
     unzip -o "${zip_file}" "${src_path}/*" -d "${target_dir}"
     mv "${target_dir}/${src_path}/"* "${target_dir}"
     rm -rf "${target_dir:?}/debian-${pkg_name}-pkg-${version}"
   }
   extract_src "i2b2" "${I2B2_DEBIAN_RELEASE}"
   extract_src "dwh" "${DWH_DEBIAN_RELEASE}"
}

build_debian_pkgs() {
  echo "Building debian packages"


}


prepare_postgresql_docker() {
  echo "Preparing PostgreSQL Docker image..."
  mkdir -p "${DIR_BUILD}/database"
  sed -e "s/__POSTGRESQL_VERSION__/${POSTGRESQL_VERSION}/g" "${DIR_SRC}/database/Dockerfile" > "${DIR_BUILD}/database/Dockerfile"
  # TODO copy i2b2 und dwh package sql scripts to build/
  cp "${DIR_SRC}/database/sql/update_wildfly_host.sql" "${DIR_BUILD}/database/sql/update_wildfly_host.sql"
}

<<'###BLOCK-COMMENT'
prepare_apache2_docker() {
  echo "Preparing Apache2 Docker image..."
  mkdir -p "${DIR_BUILD}/httpd"
  sed -e "s/__APACHE_VERSION__/${APACHE_VERSION_PHP_DOCKER}/g" "${DIR_SRC}/httpd/Dockerfile" > "${DIR_BUILD}/httpd/Dockerfile"
  download_and_extract_i2b2_webclient "/httpd/webclient"
  configure_i2b2_webclient "/httpd/webclient" "wildfly"

  echo "Preparing Apache2 Docker image..."
  mkdir -p "${DIR_BUILD}/httpd"
  sed -e "s|__BASE_IMAGE__|${BASE_IMAGE_NAMESPACE}-httpd|g" "${DIR_SRC}/httpd/Dockerfile" >"${DIR_BUILD}/httpd/Dockerfile"
  copy_apache2_proxy_config "/httpd" "wildfly"
}
###BLOCK-COMMENT

<<'###BLOCK-COMMENT'
prepare_wildfly_docker() {
  echo "Preparing WildFly Docker image..."
  mkdir -p "${DIR_BUILD}/wildfly"
  sed -e "s/__UBUNTU_VERSION__/${UBUNTU_VERSION_WILDFLY_DOCKER}/g" "${DIR_SRC}/wildfly/Dockerfile" > "${DIR_BUILD}/wildfly/Dockerfile"
  download_and_extract_wildfly "/wildfly/wildfly"
  configure_wildfly "/wildfly/wildfly"
  download_and_copy_jdbc_driver "/wildfly/wildfly/standalone/deployments"
  download_and_copy_i2b2_war "/wildfly/wildfly/standalone/deployments"

  echo "Preparing WildFly Docker image..."
  mkdir -p "${DIR_BUILD}/wildfly"
  sed -e "s|__BASE_IMAGE__|${BASE_IMAGE_NAMESPACE}-wildfly|g" "${DIR_SRC}/wildfly/Dockerfile" >"${DIR_BUILD}/wildfly/Dockerfile"
  download_and_copy_dwh_j2ee "/wildfly"
  copy_aktin_properties "/wildfly"
  download_and_copy_aktin_import_scripts "/wildfly/import-scripts"
  copy_wildfly_config "/wildfly"
}
###BLOCK-COMMENT

clean_up_old_docker_images() {
  echo "Cleaning up old Docker images and containers..."
  local images=("database" "wildfly" "httpd")
  for image in "${images[@]}"; do
    local full_image_name="${IMAGE_NAMESPACE}-${image}"

    # Stop and remove running containers based on the image
    local container_ids
    container_ids=$(docker ps -a -q --filter "ancestor=${full_image_name}:latest")
    if [ -n "${container_ids}" ]; then
      echo "Stopping and removing containers for image ${full_image_name}:latest"
      docker stop ${container_ids} || true
      docker rm ${container_ids} || true
    else
      echo "No containers found for image ${full_image_name}:latest"
    fi

    # Remove the Docker image
    if docker images "${full_image_name}:latest" -q >/dev/null; then
      echo "Removing image ${full_image_name}:latest"
      docker image rm "${full_image_name}:latest" || true
    else
      echo "Image ${full_image_name}:latest does not exist"
    fi
  done
}

build_docker_images() {
  echo "Building Docker images..."
  cwd="$(pwd)"
  cd "${DIR_SRC}"
  docker compose build
  cd "${cwd}"
}

main() {
  set -euo pipefail
  load_docker_environment_variables
  download_artifacts "true"
  extract_artifacts


  #prepare_postgresql_docker
  #clean_up_old_docker_images
  #build_docker_images
}

main
