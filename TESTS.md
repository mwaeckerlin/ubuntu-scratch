# Tests

Register of all tests, sorted by the [FEATURES.md](FEATURES.md) number each test covers. `npm test` runs everything; the guard `tests/docs-contract.sh` fails when a feature has no test entry here.

## Image contract

- **F1** `tests/config-contract.sh` › runs_as_somebody, passwd_somebody, passwd_coder, home_somebody, home_coder, ids_somebody, ids_coder, no_user_ubuntu — both users and their homes exist with the ids and the shell of `mwaeckerlin/scratch`, the image runs as `somebody`, the user and group `ubuntu` are gone.
- **F2** `tests/config-contract.sh` › shared_group_500_with_somebody — group `shared-access` has id 500 and contains `somebody`.
- **F3** `tests/config-contract.sh` › env_RUN_USER … env_ALLOW_BUILD, package_commands_work — every variable has its documented value, and a build on Ubuntu searches, installs and removes a package and then removes the package cache and `apt` with them.
- **F4** `tests/config-contract.sh` › env_LANG, child_lang_build_arg — the default language, and a child image built with `--build-arg lang=de_CH.UTF-8` carries it.
- **F5** `tests/config-contract.sh` › env_PS1_shows_container — the prompt shows the container name.
- **F6** `tests/image-contract.sh` › no sh, no bash, no busybox, no perl — the image is headless.

## Workflow contract

- **F7** `tests/workflow-contract.sh` of `mwaeckerlin/scratch` — the reusable workflow selects exactly the images a repository publishes; this repository calls it from `.github/workflows/docker.yml`.
