# CI/CD and repository rules

What runs on GitHub for this repository and which rules protect `main`, `dev` and release tags. The git hooks that run on your machine are described in the [root README](../../README.md#checks-and-gates).

## On a pull request

These checks appear on a pull request into `main` or `dev`.

| Check | Workflow | Required to merge |
| --- | --- | --- |
| `verify / verify` | `verify.yml`, lints Dockerfiles, shell scripts and workflow files | yes |
| `review / review` | `scan-dependencies.yml`, fails on new dependencies with a known vulnerability of severity high or critical | yes |
| `analyze / analyze` | `scan-codeql.yml`, CodeQL scan of the workflow files | not as a check, but the ruleset on `main` blocks the merge on CodeQL errors or security alerts of severity high or above |
| `CodeQL` | no workflow file, GitHub code scanning posts it with the result of the CodeQL scan | not as a check, the same code scanning rule applies |

## Workflows

`verify.yml`, `scan-codeql.yml`, `scan-dependencies.yml`, `scan-scorecard.yml`, `scan-image.yml` and `scan-eol.yml` only hold the triggers. Their jobs live as reusable workflows in [aktin-github-scripts](https://github.com/aktin/aktin-github-scripts/tree/main/.github/workflows) and are called at `@main`. The actions they use are pinned to commit SHAs there. `release.yml` and `rebuild-on-base-update.yml` call shared workflows too and have jobs of their own. The [README of aktin-github-scripts](https://github.com/aktin/aktin-github-scripts#workflows) lists every shared workflow.

What each workflow does and when it runs. A pull request means one into `main` or `dev`. Schedules are in UTC and run on `main`:

| Workflow | Pull request | Push to `main` | Schedule | Other | What happens |
| --- | --- | --- | --- | --- | --- |
| `verify.yml` | yes | yes | | | Starts the shared `verify-common.yml`. It checks the Dockerfiles with hadolint, the shell scripts with shellcheck and the workflow files with actionlint. The run fails when hadolint reports an error, shellcheck a warning or worse, or actionlint any finding |
| `scan-dependencies.yml` | yes | | | | Compares the dependencies before and after the pull request and fails when a newly added one has a known vulnerability of severity high or critical. On failure it writes the findings as a comment into the pull request |
| `scan-codeql.yml` | yes | yes | Mondays 03:00 | | Scans the workflow files with CodeQL for security mistakes, for example script injection or token permissions that are too broad, and reports the findings in the Security tab. Dockerfiles, shell scripts and SQL are not scanned |
| `scan-scorecard.yml` | | yes | Mondays 04:00 | | Rates the security practices of the repository, for example branch rules, pinned actions, token permissions and code review, publishes the score to OpenSSF and to the Security tab and feeds the badge in the root README. It changes nothing |
| `scan-image.yml` | | | every day 02:00 | manual start | Scans the three published `latest` images with Trivy for known vulnerabilities. Findings of severity high and critical appear in the Security tab. The run does not fail on findings |
| `scan-eol.yml` | | | 1st of each month 05:00 | manual start | Reads PostgreSQL, Ubuntu and PHP from `src/resources/versions` and opens an issue `EOL: <product> <cycle>` for each one whose end of life on endoflife.date is at most 30 days away. A version that already has such an issue, open or closed, is skipped |
| `rebuild-on-base-update.yml` | | | every day 01:00 | manual start | Starts `check-base-image.yml` once per image and collects the images whose base image has a new digest. On `main` it then starts the shared `build-publish-image.yml`, which runs `src/build.sh` for these images only and pushes and attests them. The new build replaces the image behind its version tag and behind `latest`. The image it replaces stays as an untagged version and is deleted afterwards. A manual start on another branch stops after the comparison |
| `check-base-image.yml` | | | | called by `rebuild-on-base-update.yml` | Reads the base image from the `FROM` line of one Dockerfile, asks Docker Hub for its current digest and compares it with the `org.opencontainers.image.base.digest` label of the published `latest` image |
| `release.yml` | | | | tag `v*` | Runs four jobs one after the other. `verify` repeats the checks of `verify.yml`. `images` starts the shared `build-publish-image.yml`, which runs `src/build.sh`, pushes the three images to GHCR, generates one SBOM per image, attests build provenance and SBOM at GitHub, attests `compose.yml` and deletes the untagged versions of the three packages. `compose-commit` commits the generated `compose.yml` to the branch `generated`. `publish` starts the shared `publish-release.yml`, which writes the release notes from the commit history with git-cliff and creates the GitHub Release with `compose.yml` and one SBOM file per image attached. It fails when it finds no file to attach |

In `verify.yml` and `scan-codeql.yml` a newer run for the same pull request or branch cancels the one that is still running.

How to verify the build provenance and the SBOM of an image is described in the [root README](../../README.md#verification-of-container-images). How to test the workflows on your machine is described in [test/README.md](test/README.md).

Dependabot is configured in `.github/dependabot.yml`. Once a week it opens one grouped pull request against `dev` for the GitHub Actions referenced in the workflow files. Dependabot alerts and security updates are switched on in the repository settings and report known vulnerabilities in dependencies that are already in use. Security updates always open their pull requests against `main`.

## Gates on `main` and `dev`

Branch ruleset `default` on `main`:

| Rule | Meaning |
| --- | --- |
| Pull request required | No direct pushes. Merge commit only, 1 approval, code owner review, approvals dismissed by a new push, approval after the last push, all review threads resolved |
| Required checks | `verify / verify` and `review / review` must pass |
| Code scanning | CodeQL must have analysed the head commit without errors or security alerts of severity high or above |
| Signed commits | Every commit on `main` is signed. Merge commits are signed by GitHub |
| No force push, no delete | History on `main` is append-only |

Branch ruleset `dev` on `dev`: pull request required with squash merge only, 1 approval and resolved review threads, the same required checks, signed commits, no force push and no delete.

Approvals come from people. GitHub Actions cannot create or approve pull requests, auto-merge is off, and no app or bot is on the bypass list. Organisation admins can bypass every rule. Other branches have no rules.

The repository settings add to the rulesets. Only collaborators can open pull requests. Workflows on a pull request from a fork wait for an approval when the author is an external contributor. The head branch is deleted after a merge. Secret scanning with push protection is on, so GitHub blocks a push in which it finds a secret. The workflow token can only read by default, a job that needs more lists its permissions in the workflow file. CodeQL default setup is off, so `scan-codeql.yml` is the only CodeQL scan. The packages `notaufnahme-dwh-*` list `docker-aktin-dwh` with the role Admin under Manage Actions access, so the workflows can delete untagged versions.

## Gates on tags `v*`

Tag ruleset `release-tags`: only maintainers and admins can create, move or delete release tags. A tag starts the release workflow, so this decides who can cut a release.

Releases are immutable. Once a release is published, its files cannot be changed or deleted and its tag cannot be moved.
