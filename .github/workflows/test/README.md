# Local workflow tests with `act`

`run.sh` tests the workflows in `.github/workflows` on your machine with [`act`](https://github.com/nektos/act). Nothing is pushed or published.

## Prerequisites

- Docker installed and running
- `act` 0.2.81 or newer ([install guide](https://nektosact.com/installation/index.html))

## How to run

```bash
./.github/workflows/test/run.sh
```

The script prints one result line per workflow and exits with an error when a test fails.

## What is tested

A dry run resolves every job of a workflow and every call of a shared workflow without starting containers. A run executes the workflow in local containers.

| Workflow                     | Dry run | Run                                      |
|------------------------------|---------|------------------------------------------|
| `verify.yml`                 | yes     | yes                                      |
| `scan-codeql.yml`            | yes     | no                                       |
| `scan-dependencies.yml`      | yes     | no                                       |
| `scan-scorecard.yml`         | yes     | no                                       |
| `scan-security.yml`          | yes     | no                                       |
| `rebuild-on-base-update.yml` | yes     | no                                       |
| `check-base-image.yml`       | yes     | yes, through `test-check-base-image.yml` |
| `release.yml`                | no      | no                                       |

`release.yml` and the scans only run completely on GitHub.

## Files

- `run.sh`: starts all tests
- `pull-request.json`: the pull request event the tests use
- `test-check-base-image.yml`: calls `check-base-image.yml` for the database image
