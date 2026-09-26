# Docker Scratch Image for Ubuntu with Definitions and Non Root User

Docker image from scratch with the basic definitions of an Ubuntu system:
 - a non root user to run your services
 - a non root user to build your services
 - some variables to be used
 - a nice command line prompt

It is [mwaeckerlin/scratch](https://github.com/mwaeckerlin/scratch) for software built on Ubuntu: the same users, groups and variables, with the package commands of `apt` instead of `apk`. Use it where the runtime artifacts need the glibc of Ubuntu and cannot run on Alpine's musl.

Image size: ca. 11kB (may change)

## Production Runtime Base

This image is the **runtime base** of the Ubuntu branch of the mwaeckerlin image family: use it as the **final stage** of every multi-stage build whose build stages run on Ubuntu. It contains no shell, no package manager, no libraries and no tools at all, and it already switches to the unprivileged `${RUN_USER}`, so every derived image starts non-root and headless by default. The C library, the dynamic loader and every other library the service needs are copied from the build stage together with the service.

Do the actual building in a build image such as [mwaeckerlin/ubuntu-very-base](https://github.com/mwaeckerlin/ubuntu-very-base) — a **build-only** image that must never run in production — then copy only the required runtime artifacts into the final stage based on this image.

## Compile Time Arguments

- `lang` to set language, defaults to `en_US.UTF-8`

## Environment Arguments

The environment variables are intended to be used in derived images. They are not intended to be changed. Just use them instead of hard coding in your images.

### User Variables

Use these variables for user name, group and home:

- `RUN_USER`: set to `somebody`
- `RUN_GROUP`: set to `somebody`
- `RUN_HOME`: set to `/home/somebody`

If you need to share data on volumes between containers, and if you therefore must have a predefined group id, then use the following:

  - `SHARED_GROUP_NAME`: set to `shared-access`
  - `SHARED_GROUP_ID`: set to `500`

The users have the ids of [mwaeckerlin/scratch](https://github.com/mwaeckerlin/scratch): `somebody` uid 100 gid 1000, `coder` uid 101 gid 1001, so a volume is shared between images of both families. The default user `ubuntu` of the Ubuntu image is removed.

### Build Variables

Use these variables in `RUN` commands in your docker file. E.g. install package `gcc` (the GNU Compiler Collection) using: `RUN apt-get update && $PKG_INSTALL gcc`, or give the run user access to path `/target`: `RUN $ALLOW_USER /target`

  - `PKG_INSTALL`: set to `apt-get install --no-install-recommends --no-install-suggests -y`; needs the package lists of `apt-get update`
  - `PKG_REMOVE`: set to `apt-get autoremove --purge -y --allow-remove-essential`
  - `PKG_SEARCH`: set to `apt-cache search`
  - `PKG_CLEANUP1`: removes the downloaded packages, set to `apt-get clean`
  - `PKG_CLEANUP2`: removes the package manager and its keys, set to `dpkg --purge --force-remove-essential --force-depends apt ubuntu-keyring`
  - `ALLOW_USER`: give access to a path to `$RUN_USER`, set to `chown -R ${RUN_USER}:${RUN_GROUP}`
  - `ALLOW_BUILD`: give access to a path to `$BUILD_USER`, set to `chown -R ${BUILD_USER}:${BUILD_GROUP}`

Use these variables for user name, group and home at build time, use `$RUN_USER` at run time:

  - `BUILD_USER`: set to `coder`
  - `BUILD_GROUP`: set to `coder`
  - `BUILD_HOME`: set to `/home/coder`

Internally used system variables:

  - `LANG`: set to build argument `${lang}`, normally set to `en_US.UTF-8`; the image carries no locale data, so a glibc program falls back to the locale `C` unless its final stage copies `/usr/lib/locale/locale-archive` from a build stage that ran `locale-gen`
  - `PS1`: set to a nice console prompt

## Publishing on Docker Hub

The image is built for `linux/amd64` and `linux/arm64`, tested and published on every push, on a weekly schedule on Monday at 03:17 and on a manual start, by the reusable workflow of [mwaeckerlin/scratch](https://github.com/mwaeckerlin/scratch#publishing-on-docker-hub), which describes the setup. The repository needs the secret `DOCKERHUB_TOKEN`.

## Build and Test

```bash
$ npm run build
$ npm test
```

`npm test` runs the docs contract (every feature in [FEATURES.md](FEATURES.md) has a test in [TESTS.md](TESTS.md)), the image contract (no shell, no busybox, no perl) and the config contract (users, groups, variables, the language build argument, and the package commands run on Ubuntu).
