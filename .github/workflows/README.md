# CI/CD and repository rules

What runs on GitHub for this repository and which rules protect `main`, `dev` and release tags. The git hooks that run on your machine are described in the [root README](../../README.md#checks-and-gates).

## On a pull request to `dev` or `main`

| Check             | Workflow                                                                      | Required to merge                                                                                                       |
|-------------------|-------------------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------|
| `verify / verify` | `ci.yml` starts `verify.yml`, which lints Dockerfiles, shell scripts and workflows | yes                                                                                                                     |
| `review`          | `dependency-review.yml`, fails on new dependencies with high or critical CVEs | yes                                                                                                                     |
| `analyze`         | `codeql.yml`, CodeQL scan of the workflow files                               | not as a check, but the ruleset on `main` blocks the merge on CodeQL errors or security alerts of severity high or above |

## Workflows

What each workflow does and when it runs. Schedules are in UTC and run on `main`:

| Workflow                         | Pull request to `dev` or `main` | Push to `main` | Schedule        | Other        | What happens |
|----------------------------------|---------------------------------|----------------|-----------------|--------------|--------------|
| `ci.yml`                         | yes                             | yes            |                 |              | Has no logic of its own. It starts `verify.yml`, which checks the Dockerfiles with hadolint, the shell scripts with shellcheck and the workflow files with actionlint. The run fails when hadolint reports an error, shellcheck a warning or worse, or actionlint any finding |
| `dependency-review.yml`          | yes                             |                |                 |              | Compares the dependencies before and after the pull request and fails when a newly added one has a known vulnerability of severity high or critical |
| `codeql.yml`                     | yes                             | yes            |                 |              | Scans the workflow files for security mistakes, for example script injection or token permissions that are too broad, and reports the findings in the Security tab. Dockerfiles, shell scripts and SQL are not scanned |
| `scorecard.yml`                  |                                 | yes            | Mondays 04:00   |              | Rates the security practices of the repository, for example branch rules, pinned actions, token permissions and code review, publishes the score to OpenSSF and feeds the badge in the root README. It changes nothing |
| `scheduled-security-updates.yml` |                                 |                | every day 01:00 | manual start | Asks Docker Hub for the current postgres, ubuntu and php base images and compares each with the `org.opencontainers.image.base.digest` label of the published `latest` image. When one differs it starts `build-deploy-docker.yml`, which rebuilds, scans, pushes, signs and attests the images |
| `release-tag-trigger.yml`        |                                 |                |                 | tag `v*`     | Starts `build-deploy-docker.yml` to build, scan, push, sign and attest the images. Then it writes the release notes from the commit history with git-cliff, stores the generated `compose.yml` under `generated/` on `main` and creates the GitHub Release with `compose.yml` attached |

Dependabot is configured in `.github/dependabot.yml`. Once a week it opens one grouped pull request against `dev` with updates for the GitHub Actions used in the workflows. Dependabot alerts and security updates are switched on in the repository settings and report known vulnerabilities in dependencies that are already in use.

## Gates on `main` and `dev`

Branch ruleset `default` on `main`:

| Rule                     | Meaning                                                                                                                              |
|--------------------------|--------------------------------------------------------------------------------------------------------------------------------------|
| Pull request required    | No direct pushes. Merge commit only, 1 approval, code owner review, approval after the last push, all review threads resolved        |
| Required checks          | `verify / verify` and `review` must pass                                                                                             |
| Code scanning            | CodeQL must have analysed the head commit without errors or security alerts of severity high or above                                |
| Signed commits           | Every commit on `main` is signed. Merge commits are signed by GitHub                                                                  |
| No force push, no delete | History on `main` is append-only                                                                                                     |

Branch ruleset `dev` on `dev`: pull request required with squash merge only, 1 approval and resolved review threads, the same required checks, signed commits, no force push and no delete.

Approvals come from people. GitHub Actions cannot create or approve pull requests, auto-merge is off, and no app or bot is on the bypass list. Organisation admins can bypass every rule. Other branches have no rules.

## Gates on tags `v*`

Tag ruleset `release-tags`: only maintainers and admins can create, move or delete release tags. A tag starts the release workflow, so this decides who can cut a release.
