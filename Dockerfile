FROM ubuntu AS ubuntu

FROM scratch AS environment
ARG lang="en_US.UTF-8"

# change in children:
ENV CONTAINERNAME="ubuntu-scratch"

ENV RUN_USER="somebody"
ENV RUN_GROUP="somebody"
ENV RUN_HOME="/home/somebody"

ENV BUILD_USER="coder"
ENV BUILD_GROUP="coder"
ENV BUILD_HOME="/home/coder"

ENV LANG="${lang}"
ENV SHARED_GROUP_NAME="shared-access"
ENV SHARED_GROUP_ID="500"
ENV PS1='\[\033[36;1m\]\u\[\033[97m\]@\[\033[32m\]${CONTAINERNAME}[\[\033[36m\]\h\[\033[97m\]]:\[\033[37m\]\w\[\033[0m\]\$ '

ENV PKG_INSTALL="apt-get install --no-install-recommends --no-install-suggests -y"
ENV PKG_REMOVE="apt-get autoremove --purge -y --allow-remove-essential"
ENV PKG_SEARCH="apt-cache search"
ENV PKG_CLEANUP1="apt-get clean"
ENV PKG_CLEANUP2="dpkg --purge --force-remove-essential --force-depends apt ubuntu-keyring"
ENV ALLOW_USER="chown -R ${RUN_USER}:${RUN_GROUP}"
ENV ALLOW_BUILD="chown -R ${BUILD_USER}:${BUILD_GROUP}"

FROM environment AS user
COPY --from=ubuntu / /
# the default user `ubuntu` of the Ubuntu image must not reach /etc/passwd of the final stage
RUN userdel -r ubuntu 2>/dev/null; groupdel ubuntu 2>/dev/null; true
RUN groupadd -g $SHARED_GROUP_ID $SHARED_GROUP_NAME
RUN groupadd "${RUN_GROUP}"
# the uids and the shell of mwaeckerlin/scratch, so both families share volumes;
# useradd would choose 999 and 998 and /bin/sh
RUN useradd --system --create-home --uid 100 --shell /usr/sbin/nologin --gid "${RUN_GROUP}" "${RUN_USER}"
RUN usermod -aG ${SHARED_GROUP_NAME} ${RUN_USER}
RUN groupadd "${BUILD_GROUP}"
RUN useradd --system --create-home --uid 101 --shell /usr/sbin/nologin --gid "${BUILD_GROUP}" "${BUILD_USER}"

FROM environment AS production
COPY --from=user /etc/passwd /etc/passwd
COPY --from=user /etc/group /etc/group
COPY --from=user --chown=${RUN_USER} /home/${RUN_USER}  /home/${RUN_USER}
COPY --from=user --chown=${BUILD_USER} /home/${BUILD_USER}  /home/${BUILD_USER}
USER $RUN_USER

# allow derived images to overwrite the language
ONBUILD ARG lang
ONBUILD ENV LANG=${lang:-${LANG}}
