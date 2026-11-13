# CI/CD and repository rules

What runs on GitHub for this repository and which rules protect `main`, `dev` and release tags. The git hooks that run on your machine are described in the [root README](../../README.md#checks-and-gates).

## On a pull request to `dev` or `main`

| Check               | Workflow                                                                                                   | Required to merge                                                                                                        |
|---------------------|------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------|
| `verify / verify`   | `verify.yml` starts the shared `verify-common.yml`, which lints Dockerfiles, shell scripts and workflows   | yes                                                                                                                      |
| `review / review`   | `scan-dependencies.yml`, fails on new dependencies with a known vulnerability of severity high or critical | yes                                                                                                                      |
| `analyze / analyze` | `scan-codeql.yml`, CodeQL scan of the workflow files                                                       | not as a check, but the ruleset on `main` blocks the merge on CodeQL errors or security alerts of severity high or above |
| `CodeQL`            | no workflow of this repository, GitHub code scanning posts it with the result of the CodeQL scan           | not as a check, but the ruleset on `main` blocks the merge on CodeQL errors or security alerts of severity high or above |

## Workflows

`verify.yml`, `scan-codeql.yml`, `scan-dependencies.yml`, `scan-scorecard.yml` and `scan-image.yml` only hold the triggers. Their jobs live as reusable workflows in [aktin-github-scripts](https://github.com/aktin/aktin-github-scripts/tree/main/.github/workflows) and are called at `@main`. `release.yml` and `rebuild-on-base-update.yml` call shared workflows too and have jobs of their own. The [README of aktin-github-scripts](https://github.com/aktin/aktin-github-scripts#workflows) lists every shared workflow.

What each workflow does and when it runs. Schedules are in UTC and run on `main`:

| Workflow                         | Pull request to `dev` or `main` | Push to `main` | Schedule        | Other        | What happens |
|----------------------------------|---------------------------------|----------------|-----------------|--------------|--------------|
| `verify.yml`                         | yes                             | yes            |                 |              | Has no logic of its own. It starts the shared `verify-common.yml`, which checks the Dockerfiles with hadolint, the shell scripts with shellcheck and the workflow files with actionlint. The run fails when hadolint reports an error, shellcheck a warning or worse, or actionlint any finding |
| `scan-dependencies.yml`          | yes                             |                |                 |              | Compares the dependencies before and after the pull request and fails when a newly added one has a known vulnerability of severity high or critical |
| `scan-codeql.yml`                     | yes                             | yes            | Mondays 03:00   |              | Scans the workflow files for security mistakes, for example script injection or token permissions that are too broad, and reports the findings in the Security tab. Dockerfiles, shell scripts and SQL are not scanned |
| `scan-scorecard.yml`                  |                                 | yes            | Mondays 04:00   |              | Rates the security practices of the repository, for example branch rules, pinned actions, token permissions and code review, publishes the score to OpenSSF and feeds the badge in the root README. It changes nothing |
| `scan-image.yml` | | | every day 02:00 | manual start | Scans the three published `latest` images with Trivy for known vulnerabilities. Findings of severity high and critical appear in the Security tab. The run does not fail on findings |
| `rebuild-on-base-update.yml` |                                 |                | every day 01:00 | manual start | Starts `check-base-image.yml` once per image and collects the images whose base image has a new digest. On `main` it then starts the shared `build-publish-image.yml`, which runs `src/build.sh` for these images only and pushes, signs and attests them. The new build replaces the image behind its version tag and behind `latest`. A manual start on another branch stops after the comparison |
| `check-base-image.yml` |                                 |                |                 | called by `rebuild-on-base-update.yml` | Reads the base image from the `FROM` line of one Dockerfile, asks Docker Hub for its current digest and compares it with the `org.opencontainers.image.base.digest` label of the published `latest` image |
| `release.yml`        |                                 |                |                 | tag `v*`     | Runs four jobs, each after the one before. `verify` starts the shared `verify-common.yml` for the tagged commit. `images` starts the shared `build-publish-image.yml`, which runs `src/build.sh`, pushes the three images to GHCR, signs them with cosign, generates one SBOM per image, attests build provenance and SBOM at GitHub and attests `compose.yml`. `compose-commit` commits the generated `compose.yml` to the branch `generated`. `publish` starts the shared `publish-release.yml`, which writes the release notes from the commit history with git-cliff and creates the GitHub Release with `compose.yml` and one SBOM file per image attached. It fails when it finds no file to attach |

How to verify the build provenance, the SBOM and the signature of an image is described in the [root README](../../README.md#verification-of-container-signatures). How to test the workflows on your machine is described in [test/README.md](test/README.md).

Dependabot is configured in `.github/dependabot.yml`. Once a week it opens one grouped pull request against `dev` with updates for the GitHub Actions pinned in the workflow files. Dependabot alerts and security updates are switched on in the repository settings. Alerts report known vulnerabilities in dependencies that are already in use. Security updates open their pull requests against `main`.

## Gates on `main` and `dev`

Branch ruleset `default` on `main`:

| Rule                     | Meaning                                                                                                                              |
|--------------------------|--------------------------------------------------------------------------------------------------------------------------------------|
| Pull request required    | No direct pushes. Merge commit only, 1 approval, code owner review, approval after the last push, all review threads resolved        |
| Required checks          | `verify / verify` and `review / review` must pass                                                                                    |
| Code scanning            | CodeQL must have analysed the head commit without errors or security alerts of severity high or above                                |
| Signed commits           | Every commit on `main` is signed. Merge commits are signed by GitHub                                                                  |
| No force push, no delete | History on `main` is append-only                                                                                                     |

Branch ruleset `dev` on `dev`: pull request required with squash merge only, 1 approval and resolved review threads, the same required checks, signed commits, no force push and no delete.

Approvals come from people. GitHub Actions cannot create or approve pull requests, auto-merge is off, and no app or bot is on the bypass list. Organisation admins can bypass every rule. Other branches have no rules.

## Gates on tags `v*`

Tag ruleset `release-tags`: only maintainers and admins can create, move or delete release tags. A tag starts the release workflow, so this decides who can cut a release.

## Repository settings

| Setting                         | Meaning                                                                                |
|---------------------------------|----------------------------------------------------------------------------------------|
| Workflow token                  | Read only by default. A job that needs more lists its permissions in the workflow file |
| Pull requests                   | Only collaborators can open pull requests                                              |
| Workflows on fork pull requests | Start only after approval, for all external contributors                               |
| Head branches                   | Deleted after a merge. `dev` stays because its ruleset forbids deletion                |
| Releases                        | A release cannot be changed once it is published                                       |
| Secret scanning                 | On, with push protection. GitHub rejects a push that contains a secret                 |
| CodeQL default setup            | Off. CodeQL runs through `scan-codeql.yml`                                             |
