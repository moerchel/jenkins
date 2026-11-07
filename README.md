# jenkins

[Jenkins](https://www.jenkins.io) LTS with [Docker CLI](https://docs.docker.com/reference/cli/docker/), [Docker Compose](https://docs.docker.com/compose/) and [Docker Buildx](https://docs.docker.com/build/), so jobs can build and run Docker images. Jenkins reaches the Docker daemon of the host over TCP, e.g. through [alpinedockersocat](https://github.com/moerchel/alpinedockersocat).

Based on the official image [`jenkins/jenkins`](https://hub.docker.com/r/jenkins/jenkins) (`*-lts-jdk21`), available for the following architectures:

* amd64
* arm64

## Security warning

Access to the Docker API means **root access to the host**. Everybody who can configure or run a job in Jenkins can start privileged containers on the host. Only give trusted users these permissions, and don't make the Docker API reachable from anywhere else (see [alpinedockersocat](https://github.com/moerchel/alpinedockersocat#security-warning)).

## Available image tags

Images are published on [GitHub Container Registry](https://github.com/moerchel/jenkins/pkgs/container/jenkins):

* _latest_ / _master_: the newest release.
* _YYYYMMDD_: a specific [release](https://github.com/moerchel/jenkins/releases), e.g. `20261107`. Further releases on the same day are numbered `20261107.1`, `20261107.2`, …
* _sha-xxxxxxx_: the image built from a specific commit.

The release notes name the versions of Jenkins, Java, Debian, Docker CLI, Docker Compose and Docker Buildx in the image.

### Updates

* **Jenkins**: the Jenkins version is fixed in the `Dockerfile`. For every new LTS release, Dependabot opens a pull request; it is merged after checking the plugins, so a new Jenkins version never arrives unplanned.
* **Debian packages and Docker tools**: the image is rebuilt every Monday (around 04:17 UTC) with all Debian updates and the newest Docker CLI, Compose and Buildx. A release is only created if versions changed; the release notes list them.

Every change of the image on the `master` branch creates a release as well (changes to documentation only don't).

Before an image is published, a smoke test starts Jenkins together with alpinedockersocat and checks the health check, Docker, Compose and Buildx through the TCP connection, a job with Docker commands and the clean shutdown.

Every image is scanned with [Trivy](https://github.com/aquasecurity/trivy), all findings are listed in the repository's [Security tab](https://github.com/moerchel/jenkins/security/code-scanning). Builds with fixable HIGH or CRITICAL vulnerabilities in Debian packages are not published. Findings in Jenkins itself (`jenkins.war`, `git-lfs`) don't block a build, they are fixed by new Jenkins releases.

Old images are removed weekly from the registry: untagged images (old builds) and `sha-*` tags older than 30 days. Release images, _latest_ and _master_ are kept.

## Build instructions

Clone this repo and then:

    cd jenkins
    docker build -t jenkins .

Or pull the prebuilt image:

    docker pull ghcr.io/moerchel/jenkins:latest

## How it works

### Start and stop

The container starts as root and hands over all files in `/var/jenkins_home` that don't belong to user `jenkins` (uid 1000), e.g. files created as root in a bind mount or by containers of a build. Files that already belong to `jenkins` are not touched. Then Jenkins runs as user `jenkins`.

On `docker stop`, Jenkins gets the stop signal directly and shuts down cleanly: the build queue and the configuration are saved, running pipelines are paused and resume after the next start. A shell step that was running at that moment doesn't survive the restart. Jenkins usually stops within a few seconds; to be safe, allow more time than the Docker default of 10 seconds, e.g. `stop_grace_period: 2m` in compose.

### Health check

The container is `healthy` as soon as Jenkins is fully started and answers `/login`. Port and path prefix are taken from `JENKINS_OPTS` (`--httpPort=…`, `--prefix=…`). During the first 10 minutes the state is checked every 5 seconds, so even a Jenkins with many plugins has enough time to start.

Traefik only routes to containers that are `healthy`, so Jenkins is reachable through Traefik once it has fully started.

### Docker in jobs

`DOCKER_HOST` tells the Docker CLI where the daemon is, e.g. `tcp://dockersocat:2375`. `docker`, `docker compose`, `docker-compose` and `docker buildx` are available.

* `docker build` uses the classic builder. Set `DOCKER_BUILDKIT=1` (in the container or in a job) to use BuildKit instead. `docker buildx build` always uses BuildKit.
* The Docker daemon runs on the host, so paths in bind mounts (`docker run -v /path:/path`) are paths **on the host**, not in the Jenkins container. A workspace like `/var/jenkins_home/workspace/job` only exists on the host if `jenkins_home` is a bind mount with the same path on the host and in the container (e.g. `/var/jenkins_home:/var/jenkins_home`). Otherwise pass files with the build context, `docker cp` or a named volume.

### Watchtower

[Watchtower](https://github.com/nicholas-fedor/watchtower) restarts Jenkins with every new release, which interrupts running builds (see [Start and stop](#start-and-stop)). Releases of the weekly rebuild are published on Mondays around 04:30 UTC. To be safe, give Jenkins more time for the shutdown than the Watchtower default of 10 seconds with `--stop-timeout 120s` (or `WATCHTOWER_TIMEOUT=120s`).

To update Jenkins manually instead, use a release tag (e.g. `ghcr.io/moerchel/jenkins:20261107`) or disable Watchtower for the container with the label `com.centurylinklabs.watchtower.enable=false`.

## docker compose

A simple setup with Jenkins on port 8080. Only containers in the network `docker-api` can reach the Docker API:

```yaml
services:
  jenkins:
    image: ghcr.io/moerchel/jenkins:latest
    restart: unless-stopped
    stop_grace_period: 2m
    environment:
      DOCKER_HOST: tcp://dockersocat:2375
    depends_on:
      - dockersocat
    ports:
      - '8080:8080'
      # Only needed for inbound agents
      - '50000:50000'
    volumes:
      - jenkins_home:/var/jenkins_home
    networks:
      - default
      - docker-api

  dockersocat:
    image: ghcr.io/moerchel/alpinedockersocat:latest
    restart: unless-stopped
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    networks:
      - docker-api

volumes:
  jenkins_home:

networks:
  docker-api:
    internal: true
```

Behind [Traefik](https://doc.traefik.io/traefik/) on `https://example.org/jenkins`, with a local Docker registry for the built images. The networks `jenkins` and `traefik` are created outside of this file:

```yaml
services:
  jenkins:
    image: ghcr.io/moerchel/jenkins:latest
    restart: unless-stopped
    stop_grace_period: 2m
    environment:
      DOCKER_HOST: tcp://dockersocat:2375
      JENKINS_OPTS: --prefix=/jenkins
    depends_on:
      - dockersocat
    volumes:
      - /path/to/jenkins:/var/jenkins_home
    networks:
      - jenkins
      - traefik
    labels:
      - traefik.enable=true
      - traefik.docker.network=traefik
      - traefik.http.routers.jenkins.entrypoints=websecure
      - traefik.http.routers.jenkins.rule=Host(`example.org`) && PathPrefix(`/jenkins`)
      - traefik.http.routers.jenkins.tls=true
      - traefik.http.routers.jenkins.tls.certresolver=letsencrypt
      - traefik.http.services.jenkins.loadbalancer.server.port=8080

  dockersocat:
    image: ghcr.io/moerchel/alpinedockersocat:latest
    restart: unless-stopped
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    networks:
      - jenkins

  registry:
    image: registry:3
    restart: unless-stopped
    environment:
      REGISTRY_STORAGE_DELETE_ENABLED: 'true'
    ports:
      - '127.0.0.1:5000:5000'
    volumes:
      - /path/to/registry:/var/lib/registry
    networks:
      - jenkins

networks:
  jenkins:
    external: true
  traefik:
    external: true
```

`--prefix` has to match the `PathPrefix` of the Traefik rule. Traefik passes the path unchanged, Jenkins serves everything below `/jenkins`.

## License

[MIT](LICENSE)
