# Jenkins LTS. Dependabot opens a pull request for every new LTS release
# (only tags ending in -lts-jdk21), so core updates are merged deliberately.
FROM jenkins/jenkins:2.580.2-lts-jdk21

LABEL org.opencontainers.image.title="jenkins" \
      org.opencontainers.image.description="Jenkins LTS with Docker CLI, Docker Compose and Docker Buildx" \
      org.opencontainers.image.source="https://github.com/moerchel/jenkins" \
      org.opencontainers.image.licenses="MIT"

# Starts as root to fix the ownership in JENKINS_HOME, entrypoint.sh then
# runs Jenkins as user jenkins
# hadolint ignore=DL3002,DL3066
USER root

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# SHA-256 of https://download.docker.com/linux/debian/gpg, the build fails
# if the signing key of the Docker apt repository changes
ARG DOCKER_GPG_SHA256=1500c1f56fa9e26b9b8f42452a553675796ade0807cdce11975eb98170b3a570

# Debian updates published since the base image was built, and the newest
# Docker CLI, Compose and Buildx from the Docker apt repository. The weekly
# rebuild picks up new versions of both.
# hadolint ignore=DL3005,DL3008
RUN install -d -m 0755 /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc \
    && echo "$DOCKER_GPG_SHA256  /etc/apt/keyrings/docker.asc" | sha256sum -c - \
    && . /etc/os-release \
    && printf '%s\n' 'Types: deb' 'URIs: https://download.docker.com/linux/debian' \
         "Suites: $VERSION_CODENAME" 'Components: stable' \
         "Architectures: $(dpkg --print-architecture)" 'Signed-By: /etc/apt/keyrings/docker.asc' \
         > /etc/apt/sources.list.d/docker.sources \
    && apt-get update \
    && apt-get upgrade -y \
    && apt-get install -y --no-install-recommends docker-ce-cli docker-compose-plugin docker-buildx-plugin \
    && rm -rf /var/lib/apt/lists/* \
    # docker-compose (v1 command name) and the former location of the docker binary
    && ln -s /usr/libexec/docker/cli-plugins/docker-compose /usr/local/bin/docker-compose \
    && ln -s /usr/bin/docker /usr/local/bin/docker

# "docker build" uses the classic builder, set DOCKER_BUILDKIT=1 to use
# BuildKit instead. "docker buildx build" always uses BuildKit.
ENV DOCKER_BUILDKIT=0

COPY --chmod=755 entrypoint.sh healthcheck.sh /usr/local/bin/

# Jenkins needs a while to start, especially with many plugins. During the
# start period the state is checked every 5 seconds.
HEALTHCHECK --interval=60s --timeout=10s --start-period=10m --start-interval=5s --retries=3 \
  CMD ["/usr/local/bin/healthcheck.sh"]

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/usr/local/bin/entrypoint.sh"]
