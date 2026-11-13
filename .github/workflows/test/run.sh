#!/bin/bash
#--------------------------------------
# Script Name:  run.sh
# Purpose:      Tests the workflows in .github/workflows locally with act. A dry run resolves every job and every call of a shared workflow
#               without starting containers. The workflows that need nothing from GitHub then run for real.
#--------------------------------------

set -euo pipefail

command -v act >/dev/null || {
  echo "Error: act is required but not installed." >&2
  exit 1
}

DIR_TEST="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly DIR_TEST
readonly DIR_WORKFLOWS="${DIR_TEST}/.."
cd "${DIR_TEST}/../../.."

RESULTS=()
FAILED=false

# Start act for one workflow and one event and record whether it passed
test_workflow() {
  local mode="$1"
  local event="$2"
  local workflow="$3"
  shift 3
  echo "${mode}: ${workflow} on ${event}"
  if act "${event}" --workflows "${DIR_WORKFLOWS}/${workflow}" "$@"; then
    RESULTS+=("passed  ${mode}: ${workflow}")
  else
    RESULTS+=("FAILED  ${mode}: ${workflow}")
    FAILED=true
  fi
}

# Resolve the jobs of one workflow for one event without running them
dry_run() {
  test_workflow "dry run" "$@" --dryrun
}

# Run one workflow for one event in local containers
run() {
  test_workflow "run" "$@"
}

main() {
  dry_run pull_request verify.yml --eventpath "${DIR_TEST}/pull-request.json"
  dry_run pull_request scan-codeql.yml --eventpath "${DIR_TEST}/pull-request.json"
  dry_run pull_request scan-dependencies.yml --eventpath "${DIR_TEST}/pull-request.json"
  dry_run schedule scan-scorecard.yml
  dry_run schedule scan-security.yml
  dry_run schedule rebuild-on-base-update.yml

  run pull_request verify.yml --eventpath "${DIR_TEST}/pull-request.json"
  run workflow_dispatch test/test-check-base-image.yml

  printf '%s\n' "" "Results:" "${RESULTS[@]}"
  if [[ "${FAILED}" == true ]]; then
    exit 1
  fi
}

main
