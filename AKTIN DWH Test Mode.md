# AKTIN DWH Test Mode

Oct 1, 2026 · @Alexander Ivanets

## Overview

With `TEST_DATABASE=true`, the database container runs a separate, disposable PostgreSQL cluster with six synthetic test patients. The production volume stays mounted but is never opened.

The default is `false`. Without the flag, sites get the original behaviour: no extra containers, volumes, processes or databases. Only the database service receives the flag; WildFly is unchanged.

```bash
TEST_DATABASE=true docker compose up -d
```

The flag can also live in the env file. A variable set in the shell takes precedence over `--env-file`.

## How it works

Test mode is a different `PGDATA`. Everything else is the official postgres image's normal first-time initialization.

1. `entrypoint.sh` sees the flag and exports `PGDATA=/var/lib/postgresql/test-data`. This directory lives in the container's writable layer, not on the `pg_data` volume.
2. Update scripts only run when `PGDATA` already holds a cluster, so they never touch the production volume in test mode.
3. The official `docker-entrypoint.sh` finds an empty directory, runs `initdb`, then runs `/docker-entrypoint-initdb.d/` in alphabetical order: `init.sql` first, then `zz-init-test-database.sh`.
4. `zz-init-test-database.sh` loads `/usr/local/share/aktin/i2b2_test_fixture.sql` into `i2b2`, but only if `PGDATA` is the test directory. It checks the directory, not the flag, so a production first install can never receive test patients.
5. Database names stay `i2b2` and `aktin`, so WildFly connects exactly as in production.

Files involved:

| File | Role |
| --- | --- |
| `src/resources/database/entrypoint.sh` | Switches `PGDATA` when the flag is set |
| `src/resources/database/init-test-database.sh` | Loads the fixture, test cluster only |
| `src/resources/database/i2b2_test_fixture.sql` | Test patients as a data-only dump |
| `src/docker/database/Dockerfile` | Copies both, script as `zz-…` with `chmod +x` |
| `src/build.sh` | Copies both into the build context |
| `src/docker/template.yml` | Passes the flag to `database`; TCP healthcheck |

The `zz-` prefix and `chmod +x` both matter. A `90-` prefix would sort before `init.sql`, and a non-executable `.sh` is sourced, so its `exit 0` would abort the whole initialization.

## Lifecycle

The test cluster lives exactly as long as the database container. No code ever deletes a database or a directory.

| Action | Test data afterwards |
| --- | --- |
| `docker compose down` + `up` | Fresh cluster, fixture only |
| Changing `TEST_DATABASE` | Container recreated, fresh cluster |
| Image update | Container recreated, fresh cluster from current `init.sql` |
| `docker compose restart` | Kept: same container, same writable layer |
| Switching back to `false` | Test cluster gone with the old container; production volume unchanged |

Because every recreate builds the cluster from the current image, schema updates never have to be applied to an old test cluster.

Starting a brand-new installation directly in test mode leaves the production volume empty. It is initialized normally on the first start without the flag.

## Test data

The fixture holds 6 patients, 6 encounters and 425 observations from six storyboard documents. It is a data-only `pg_dump` of the five `i2b2crcdata` tables a CDA import fills, plus `observation_fact_text_search_index_seq`.

Lookup tables (`qt_*`, `set_type`) and `concept_dimension` are excluded because `init.sql` already fills them. Including them would cause duplicate-key errors.

Regenerate the fixture when an i2b2 update changes these tables:

1. Empty `src/resources/database/i2b2_test_fixture.sql`, rebuild, and start with `TEST_DATABASE=true`.
2. Import the storyboard documents through the normal CDA import.
3. Without restarting, dump the tables and rebuild:

```bash
docker exec build-database pg_dump -U postgres -d i2b2 --data-only \
  -t i2b2crcdata.patient_dimension \
  -t i2b2crcdata.patient_mapping \
  -t i2b2crcdata.visit_dimension \
  -t i2b2crcdata.encounter_mapping \
  -t i2b2crcdata.observation_fact \
  -t i2b2crcdata.observation_fact_text_search_index_seq \
  > src/resources/database/i2b2_test_fixture.sql
```

If the import touches other tables or sequences after an update, compare row counts before and after the import and add them with `-t`.

## Healthcheck, limitations, troubleshooting

The database healthcheck uses `pg_isready -h 127.0.0.1` (TCP). During first-time initialization the official image runs a temporary server on the Unix socket only. A socket-based check reported it as healthy, WildFly started too early, and `dwh-j2ee` failed permanently with `Connection refused`. This also affected fresh production installs.

Known limitations:

- The AKTIN import statistics (Importiert, Aktualisiert, Ungültig, Fehlgeschlagen) show 0, because the fixture bypasses the CDA import.
- i2b2 PM uses the default users and passwords from `i2b2_db.sql`, not credentials changed on the production volume.
- WildFly does not know about test mode. With `DEV_MODE=false` it talks to the production broker and would answer with synthetic data. Use test mode only for development and demos.

Quick check that test mode is active:

```bash
docker exec build-database psql -U postgres -Atc "SHOW data_directory"
docker exec build-database psql -U postgres -d i2b2 -Atc "SELECT count(*) FROM i2b2crcdata.observation_fact"
```

Expected: `/var/lib/postgresql/test-data` and `425`.

If `observation_fact` is 0 in test mode, the fixture load probably failed and Docker restarted the same container, which skips initialization because `PG_VERSION` already exists. Check the database log for an error after `Loading test patients`, then run `docker compose down` and `up` to get a fresh cluster.

If `/aktin/admin` returns 404, look for a `.failed` marker in `/opt/wildfly/standalone/deployments/`. The WildFly healthcheck always passes, so compose does not catch a failed deployment.
