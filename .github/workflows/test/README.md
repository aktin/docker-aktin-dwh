# Local workflow tests with `act`

`run.sh` tests the workflows in `.github/workflows` on your machine with [`act`](https://github.com/nektos/act). Nothing is pushed or published.

## Prerequisites

- Docker installed and running
- `act` 0.2.81 or newer ([install guide](https://nektosact.com/installation/index.html))
- Network access to Docker Hub, GHCR and GitHub. The runs pull images and the shared workflows

## How to run

```bash
./.github/workflows/test/run.sh
```

The script ends with one result line per test and exits with an error when a test fails. A failed test shows `FAILED` in place of `passed`.

```
Results:
passed  dry run: verify.yml
passed  dry run: scan-codeql.yml
passed  dry run: scan-dependencies.yml
passed  dry run: scan-scorecard.yml
passed  dry run: scan-image.yml
passed  dry run: rebuild-on-base-update.yml
passed  run: verify.yml
passed  run: test/test-check-base-image.yml
```

## What is tested

A dry run resolves every job of a workflow and every call of a shared workflow without starting containers. A run executes the workflow in local containers.

| Workflow                     | Dry run                                   | Run                                      |
|------------------------------|-------------------------------------------|------------------------------------------|
| `verify.yml`                 | yes                                       | yes                                      |
| `scan-codeql.yml`            | yes                                       | no                                       |
| `scan-dependencies.yml`      | yes                                       | no                                       |
| `scan-scorecard.yml`         | yes                                       | no                                       |
| `scan-image.yml`             | yes                                       | no                                       |
| `rebuild-on-base-update.yml` | yes                                       | no                                       |
| `check-base-image.yml`       | yes, through `rebuild-on-base-update.yml` | yes, through `test-check-base-image.yml` |
| `release.yml`                | no                                        | no                                       |

`release.yml`, the scans and the rebuild of the images only run completely on GitHub.

## Files

- `run.sh`: starts all tests
- `pull-request.json`: the pull request event the tests use
- `test-check-base-image.yml`: calls `check-base-image.yml` for the database image
