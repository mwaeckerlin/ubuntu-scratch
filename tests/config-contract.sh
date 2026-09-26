#!/usr/bin/env bash
# Config contract: the definitions every derived image relies on are in place.
#
# The image has no shell, so nothing is asked inside a running container: the
# environment and the user come from `docker image inspect`, the user and
# group files are copied out of a created (never started) container, and the
# build argument `lang` is checked on a child image built FROM this one.
#
# Usage: tests/config-contract.sh IMAGE

set -uo pipefail

IMAGE="${1:?usage: tests/config-contract.sh IMAGE}"

PASS=0
FAIL=0
declare -a FAILED_NAMES

_pass() { PASS=$((PASS + 1)); echo "  PASS  $1"; }
_fail() { FAIL=$((FAIL + 1)); FAILED_NAMES+=("$1"); echo "  FAIL  $1: $2"; }

_env_is() {
    local name="$1" expected="$2"
    local value
    value=$(docker image inspect --format '{{range .Config.Env}}{{println .}}{{end}}' "${IMAGE}" | sed -n "s/^${name}=//p")
    if [[ "${value}" == "${expected}" ]]; then
        _pass "env_${name}"
    else
        _fail "env_${name}" "expected '${expected}', got '${value}'"
    fi
}

echo "==> Config contract: definitions for derived images"

if ! docker image inspect "${IMAGE}" > /dev/null 2>&1; then
    _fail "${IMAGE}_image_exists" "image not built — run 'npm run build' first"
else
    _env_is RUN_USER somebody
    _env_is RUN_GROUP somebody
    _env_is RUN_HOME /home/somebody
    _env_is BUILD_USER coder
    _env_is BUILD_GROUP coder
    _env_is BUILD_HOME /home/coder
    _env_is SHARED_GROUP_NAME shared-access
    _env_is SHARED_GROUP_ID 500
    _env_is LANG en_US.UTF-8
    _env_is PKG_INSTALL "apt-get install --no-install-recommends --no-install-suggests -y"
    _env_is PKG_REMOVE "apt-get autoremove --purge -y --allow-remove-essential"
    _env_is PKG_SEARCH "apt-cache search"
    _env_is PKG_CLEANUP1 "apt-get clean"
    _env_is PKG_CLEANUP2 "dpkg --purge --force-remove-essential --force-depends apt ubuntu-keyring"
    _env_is ALLOW_USER "chown -R somebody:somebody"
    _env_is ALLOW_BUILD "chown -R coder:coder"

    PS1_VALUE=$(docker image inspect --format '{{range .Config.Env}}{{println .}}{{end}}' "${IMAGE}" | sed -n 's/^PS1=//p')
    if [[ "${PS1_VALUE}" == *'${CONTAINERNAME}'* ]]; then
        _pass "env_PS1_shows_container"
    else
        _fail "env_PS1_shows_container" "prompt does not show the container name: '${PS1_VALUE}'"
    fi

    USER_VALUE=$(docker image inspect --format '{{.Config.User}}' "${IMAGE}")
    if [[ "${USER_VALUE}" == "somebody" ]]; then
        _pass "runs_as_somebody"
    else
        _fail "runs_as_somebody" "image user is '${USER_VALUE}'"
    fi

    CONTAINER=$(docker create --pull=never "${IMAGE}" /none)
    PASSWD=$(docker cp "${CONTAINER}:/etc/passwd" - | tar -xO)
    GROUP=$(docker cp "${CONTAINER}:/etc/group" - | tar -xO)
    HOMES=$(docker cp "${CONTAINER}:/home" - | tar -t)
    docker rm "${CONTAINER}" > /dev/null

    for user in somebody coder; do
        if echo "${PASSWD}" | grep -q "^${user}:"; then
            _pass "passwd_${user}"
        else
            _fail "passwd_${user}" "user missing in /etc/passwd"
        fi
        if echo "${HOMES}" | grep -qx "home/${user}/"; then
            _pass "home_${user}"
        else
            _fail "home_${user}" "home directory missing"
        fi
    done
    # the same ids and shell as in mwaeckerlin/scratch, so volumes are shared across both families
    for entry in 'somebody:x:100:1000:' 'coder:x:101:1001:'; do
        if echo "${PASSWD}" | grep -q "^${entry}.*:/usr/sbin/nologin$"; then
            _pass "ids_${entry%%:*}"
        else
            _fail "ids_${entry%%:*}" "expected ${entry} with /usr/sbin/nologin as in mwaeckerlin/scratch"
        fi
    done
    if echo "${PASSWD}${GROUP}" | grep -q '^ubuntu:'; then
        _fail "no_user_ubuntu" "the default user or group ubuntu of the Ubuntu image is still present"
    else
        _pass "no_user_ubuntu"
    fi
    if echo "${GROUP}" | grep -q '^shared-access:x:500:.*somebody'; then
        _pass "shared_group_500_with_somebody"
    else
        _fail "shared_group_500_with_somebody" "group shared-access:500 missing or somebody not a member"
    fi

    CHILD="${IMAGE%%:*}-config-contract-child"
    if printf 'FROM %s\n' "${IMAGE}" | docker build --quiet --build-arg lang=de_CH.UTF-8 -t "${CHILD}" - > /dev/null 2>&1; then
        CHILD_LANG=$(docker image inspect --format '{{range .Config.Env}}{{println .}}{{end}}' "${CHILD}" | sed -n 's/^LANG=//p')
        docker image rm "${CHILD}" > /dev/null
        if [[ "${CHILD_LANG}" == "de_CH.UTF-8" ]]; then
            _pass "child_lang_build_arg"
        else
            _fail "child_lang_build_arg" "child LANG is '${CHILD_LANG}'"
        fi
    else
        _fail "child_lang_build_arg" "child image does not build"
    fi

    # The package commands are only strings in this headless image; they are
    # run the way a derived build stage runs them, on the Ubuntu it is built
    # from, in the documented order: search, install, remove, the two cleanups.
    _env_value() {
        docker image inspect --format '{{range .Config.Env}}{{println .}}{{end}}' "${IMAGE}" | sed -n "s/^$1=//p"
    }
    PKG_CHILD="${IMAGE%%:*}-config-contract-pkg"
    if printf '%s\n' 'FROM ubuntu' 'ARG S I R C1 C2' 'RUN apt-get update' \
            'RUN $S ^hello$ | grep -q "^hello "' 'RUN $I hello' 'RUN hello' 'RUN $R hello' 'RUN ! command -v hello' \
            'RUN $C1' 'RUN $C2' 'RUN ! command -v apt-get' \
        | docker build --quiet \
            --build-arg S="$(_env_value PKG_SEARCH)" --build-arg I="$(_env_value PKG_INSTALL)" \
            --build-arg R="$(_env_value PKG_REMOVE)" --build-arg C1="$(_env_value PKG_CLEANUP1)" \
            --build-arg C2="$(_env_value PKG_CLEANUP2)" -t "${PKG_CHILD}" - > /dev/null; then
        docker image rm "${PKG_CHILD}" > /dev/null
        _pass "package_commands_work"
    else
        _fail "package_commands_work" "a PKG_* command fails on Ubuntu"
    fi
fi

echo ""
echo "==> Config contract results: ${PASS} passed, ${FAIL} failed"
if [[ ${FAIL} -gt 0 ]]; then
    echo "==> Failed contracts: ${FAILED_NAMES[*]}"
    exit 1
fi
