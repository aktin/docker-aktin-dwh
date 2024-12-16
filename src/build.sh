#!/bin/bash
#--------------------------------------
# Script Name:  build.sh
# Version:      1.1
# Author:       shuening@ukaachen.de, skurka@ukaachen.de, akombeiz@ukaachen.de
# Date:         05 Dec 24
# Purpose:      ToDo
#--------------------------------------

set -euo pipefail

USE_MAIN=false

usage() {
  echo "Usage: $0 [--use-main-branch]" >&2
  echo "  --use-main-branch  Optional: Download the current version from main branch instead of tagger releases" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case $1 in
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
  echo "Downloading required artifacts..."
  mkdir -p "${DIR_DOWNLOADS}"

  download_package() {
    local pkg_name="$1"
    local version="$2"
    local zip_file="${DIR_DOWNLOADS}/${pkg_name}.zip"
    # Use cached version if available
    [[ -f "${zip_file}" ]] && { echo "Using cached ${pkg_name}.zip"; return 0; }
    # Download the latest version instead
    if [ "$USE_MAIN" = true ]; then
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
     # Determine package directory based on download type (main/version)
     local pkg_dir
     pkg_dir=$([ "$USE_MAIN" = true ] && echo "main" || echo "${version}")
     local src_path="debian-${pkg_name}-pkg-${pkg_dir}/src"
     local target_dir="${DIR_DOWNLOADS}/${pkg_name}"
     # Skip extraction if sources already exist
     [[ -d "${target_dir}" ]] && { echo "Using cached ${pkg_name} sources"; return 0; }
     echo "Extracting ${pkg_name} source files..."
     mkdir -p "${target_dir}"
     unzip -qo "${zip_file}" "${src_path}/*" -d "${target_dir}"
     # Move files to target and cleanup temp dirs
     mv "${target_dir}/${src_path}/"* "${target_dir}"
     rm -rf "${target_dir:?}/debian-${pkg_name}-pkg-${pkg_dir}"
   }
   extract_src "i2b2" "${I2B2_DEBIAN_RELEASE}"
   extract_src "dwh" "${DWH_DEBIAN_RELEASE}"
}

execute_build_scripts() {
  echo "Building debian packages"

  build_package() {
    local pkg_name="$1"
    local build_script="${DIR_DOWNLOADS}/${pkg_name}/debian/build.sh"
    if [[ -x "${build_script}" ]]; then
      echo "Building ${pkg_name} package..."
      "${build_script}" --skip-deb-build
    else
      echo "Error: Build script not found or not executable for ${pkg_name}" >&2
      return 1
    fi
  }
  build_package "i2b2"
  build_package "dwh"
}

prepare_postgresql_docker(){
  echo "Preparing PostgreSQL container environment..."
  local sql_target_dir="${DIR_BUILD}/database/sql"
  mkdir -p "${sql_target_dir}"

  copy_package_sql_scripts() {
    local pkg_name="$1"
    local version=$(grep "PACKAGE_VERSION" "${DIR_SRC}/downloads/${pkg_name}/resources/versions" | cut -d'=' -f2)
    local pkg_path="${DIR_SRC}/downloads/${pkg_name}/build/aktin-notaufnahme-${pkg_name}_${version}"
    local sql_source_dir="${pkg_path}/usr/share/aktin-notaufnahme-${pkg_name}/sql"
    echo "Copying ${pkg_name} SQL scripts..."
    cp "${sql_source_dir}/"* "${sql_target_dir}"
  }
  copy_package_sql_scripts "i2b2"
  copy_package_sql_scripts "dwh"
  sed -e "s|__POSTGRESQL_VERSION__|${POSTGRESQL_VERSION}|g" -e "s|__DWH_DEBIAN_RELEASE__|${DWH_DEBIAN_RELEASE}|g" "${DIR_SRC}/docker/database/Dockerfile" > "${DIR_BUILD}/database/Dockerfile"
  cp "${DIR_RESOURCES}/database/update_wildfly_host.sql" "${sql_target_dir}"
}

# TODO: Delete duplicates from proxy.php blacklist/whitelist?
prepare_apache2_docker() {
  local wildfly_host="$1"
  echo "Preparing Apache container environment..."
  local build_dir="${DIR_BUILD}/httpd"
  mkdir -p "${build_dir}"

  deploy_i2b2_webclient() {
    local version=$(grep "PACKAGE_VERSION" "${DIR_SRC}/downloads/i2b2/resources/versions" | cut -d'=' -f2)
    local source_dir="${DIR_SRC}/downloads/i2b2/build/aktin-notaufnahme-i2b2_${version}/var/www/html/webclient"
    local target_dir="${build_dir}/webclient"
    echo "Copying i2b2 webclient..."
    cp -r "${source_dir}/" "${build_dir}"
    # Update host configurations
    sed -i "s|localhost|${wildfly_host}|g" "${target_dir}/i2b2_config_domains.json"
    sed -i -e "s|localhost|${wildfly_host}|g" -e "s|127\.0\.0\.1|${wildfly_host}|g" "${target_dir}/proxy.php"
  }
  deploy_proxy_config() {
    local version=$(grep "PACKAGE_VERSION" "${DIR_SRC}/downloads/dwh/resources/versions" | cut -d'=' -f2)
    local source_file="${DIR_SRC}/downloads/dwh/build/aktin-notaufnahme-dwh_${version}/etc/apache2/conf-available/aktin-j2ee-reverse-proxy.conf"
    echo "Deploying reverse proxy config..."
    cp "${source_file}" "${build_dir}/"
    # Update host configuration
    sed -i "s|localhost|${wildfly_host}|g" "${build_dir}/aktin-j2ee-reverse-proxy.conf"
  }
  deploy_i2b2_webclient
  deploy_proxy_config
  sed -e "s|__APACHE_VERSION__|${APACHE_VERSION}|g" -e "s|__DWH_DEBIAN_RELEASE__|${DWH_DEBIAN_RELEASE}|g" "${DIR_SRC}/docker/httpd/Dockerfile" > "${build_dir}/Dockerfile"
}


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
  download_artifacts
  extract_artifacts
  execute_build_scripts

  #clean_up_old_docker_images
  #build_docker_images
}

main
