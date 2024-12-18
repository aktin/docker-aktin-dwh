#!/bin/bash
#--------------------------------------
# Script Name:  build.sh
# Version:      1.1
# Author:       shuening@ukaachen.de, skurka@ukaachen.de, akombeiz@ukaachen.de
# Date:         05 Dec 24
# Purpose:      ToDo
#--------------------------------------

set -euo pipefail

readonly IMAGE_NAMESPACE="notaufnahme-dwh"

CLEANUP=false
FORCE_REBUILD=false
USE_MAIN=false

usage() {
  echo "Usage: $0 [--cleanup] [--use-main-branch]" >&2
  echo "  --cleanup          Optional: Remove build directory after image creation" >&2
  echo "  --force-rebuild    Optional: Force a complete image recreation" >&2
  echo "  --use-main-branch  Optional: Download the current version from main branch instead of the specific release versions set in .env" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case $1 in
    --cleanup)
      CLEANUP=true
      shift
      ;;
    --force-rebuild)
      FORCE_REBUILD=true
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
     local target_dir="${DIR_DOWNLOADS}/${pkg_name}"
     # Skip if package directory already exists
     if [[ -d "${target_dir}" ]] && [[ -d "${target_dir}/debian" ]]; then
       echo "Using cached ${pkg_name} sources"
       return 0
     fi
     # Determine package directory based on download type (main/version)
     local pkg_dir=$([ "$USE_MAIN" = true ] && echo "main" || echo "${version}")
     local src_path="debian-${pkg_name}-pkg-${pkg_dir}/src"
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
    local build_dir="${DIR_DOWNLOADS}/${pkg_name}/build"
    local build_script="${DIR_DOWNLOADS}/${pkg_name}/debian/build.sh"
    # Skip if build directory exists
    if [[ -d "${build_dir}" ]]; then
      echo "Using cached ${pkg_name} build"
      return 0
    fi
    if [[ ! -x "${build_script}" ]]; then
      echo "Error: Build script not found or not executable for ${pkg_name}" >&2
      return 1
    fi
    echo "Building ${pkg_name} package..."
    "${build_script}" --skip-deb-build
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

prepare_wildfly_docker() {
  echo "Preparing Wildfly container environment..."
  local build_dir="${DIR_BUILD}/wildfly"
  mkdir -p "${build_dir}"/{wildfly,import-scripts}

  deploy_wildfly_base() {
    local version=$(grep "PACKAGE_VERSION" "${DIR_SRC}/downloads/i2b2/resources/versions" | cut -d'=' -f2)
    local source_dir="${DIR_SRC}/downloads/i2b2/build/aktin-notaufnahme-i2b2_${version}/opt/wildfly"
    echo "Copying Wildfly server..."
    cp -r "${source_dir}/"* "${build_dir}/wildfly"
  }
  install_aktin_ds() {
    echo "Configuring Wildfly server..."
    local version=$(grep "PACKAGE_VERSION" "${DIR_SRC}/downloads/dwh/resources/versions" | cut -d'=' -f2)
    local base_dir="${DIR_SRC}/downloads/dwh/build/aktin-notaufnahme-dwh_${version}"
    local jdbc_version=$(grep "POSTGRES_JDBC_VERSION" "${DIR_SRC}/downloads/i2b2/resources/versions" | cut -d'=' -f2)
    sed -e "s|__POSTGRES_JDBC_VERSION__|${jdbc_version}|g" "${base_dir}/opt/wildfly/bin/add-aktin-config.cli" > "${build_dir}/wildfly/bin/add-aktin-config.cli"
    "${build_dir}/wildfly/bin/jboss-cli.sh" --file="${build_dir}/wildfly/bin/add-aktin-config.cli"
    rm "${build_dir}"/wildfly/standalone/configuration/standalone_xml_history/current/*
  }
  deploy_aktin_components() {
    local version=$(grep "PACKAGE_VERSION" "${DIR_SRC}/downloads/dwh/resources/versions" | cut -d'=' -f2)
    local base_dir="${DIR_SRC}/downloads/dwh/build/aktin-notaufnahme-dwh_${version}"
    echo "Copying AKTIN components..."
    cp -r "${base_dir}/var/lib/aktin/import-scripts/"* "${build_dir}/import-scripts/"
    cp -r "${base_dir}/etc/aktin/aktin.properties" "${build_dir}/"
    cp -r "${base_dir}/opt/wildfly/standalone/deployments/"* "${build_dir}/wildfly/standalone/deployments/"
  }
  # get all openjdk, python and R dependencies of debian package
  get_package_dependencies() {
   local pkg_name="$1"
   local version=$(grep "PACKAGE_VERSION" "${DIR_SRC}/downloads/${pkg_name}/resources/versions" | cut -d'=' -f2)
   local control_path="${DIR_SRC}/downloads/${pkg_name}/build/aktin-notaufnahme-${pkg_name}_${version}/DEBIAN/control"
   grep '^Depends:' "${control_path}"
  }
  local ubuntu_dependencies=$(
   { get_package_dependencies "i2b2"; get_package_dependencies "dwh"; } | \
   tr ',' '\n' | \
   grep -E 'openjdk|python3|r-' | \
   sed -e 's/([^)]*)//g' -e 's/^[[:space:]]*//' | \
   sort -u | \
   tr '\n' ' '
  )
  deploy_wildfly_base
  install_aktin_ds
  deploy_aktin_components
  sed -e "s|__UBUNTU_VERSION__|${UBUNTU_VERSION}|g" -e "s|__DWH_DEBIAN_RELEASE__|${DWH_DEBIAN_RELEASE}|g" -e "s|__UBUNTU_DEPENDENCIES__|${ubuntu_dependencies}|g" "${DIR_SRC}/docker/wildfly/Dockerfile" > "${build_dir}/Dockerfile"
}

prepare_docker_compose() {
  sed -e "s|__IMAGE_NAMESPACE__|${IMAGE_NAMESPACE}|g" "${DIR_SRC}/docker/compose.yml" > "${DIR_BUILD}/compose.yml"
}

cleanup_old_docker_images() {
  echo "Cleaning up Docker resources..."
  local -r images=("database" "wildfly" "httpd")

  for image in "${images[@]}"; do
    local full_image_name="${IMAGE_NAMESPACE}-${image}"
    # Find and remove containers using image
    if containers=$(docker ps -a -q --filter "ancestor=${full_image_name}:latest"); then
      if [ -n "$containers" ]; then
        echo "Removing containers for ${full_image_name}"
        docker rm -f $containers
      fi
    fi
    # Remove image if exists
    if docker image inspect "${full_image_name}:latest" >/dev/null 2>&1; then
      echo "Removing image ${full_image_name}"
      docker rmi "${full_image_name}:latest"
    fi
  done
}

build_docker_images() {
  echo "Building Docker images..."
  local cwd="$(pwd)"
  cd "${DIR_BUILD}"
  if [ "${FORCE_REBUILD}" = true ]; then
    echo "Forcing image rebuild..."
    docker compose build --no-cache
  else
    docker compose build
  fi
  cd "${cwd}"
  if [[ "${CLEANUP}" == true ]]; then
    echo "Cleaning up build artifacts..."
    rm -r "${DIR_BUILD}"/{database,wildfly,httpd}
  fi
}

main() {
  set -euo pipefail
  load_docker_environment_variables
  download_artifacts
  extract_artifacts
  execute_build_scripts
  prepare_postgresql_docker
  prepare_apache2_docker "wildfly"
  prepare_wildfly_docker
  prepare_docker_compose
  cleanup_old_docker_images
  build_docker_images
}

main
