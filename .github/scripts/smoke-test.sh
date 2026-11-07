#!/bin/bash
# Smoke test of the image together with alpinedockersocat:
#   - Jenkins starts (behind the path prefix /jenkins) and becomes healthy
#   - files in JENKINS_HOME that don't belong to jenkins are handed over
#   - Jenkins runs directly below tini as user jenkins with HOME set
#   - Docker CLI, Compose and Buildx work through socat, as user jenkins
#   - a freestyle job can run Docker commands
#   - "docker stop" shuts Jenkins down cleanly
#
# Usage: smoke-test.sh IMAGE [SOCAT_IMAGE]
# PREFIX (default "smoke-") is put in front of all created container,
# volume, network and image names, PORT (default 18080) is the port on
# 127.0.0.1 for Jenkins. Everything is removed at the end.
set -euo pipefail

image=$1
socat_image=${2:-ghcr.io/moerchel/alpinedockersocat:latest}
p=${PREFIX:-smoke-}
port=${PORT:-18080}
url=http://127.0.0.1:$port/jenkins

remove_test_objects() {
    docker rm -f "${p}jenkins" "${p}dockersocat" >/dev/null 2>&1 || true
    docker compose -p "${p}compose" down >/dev/null 2>&1 || true
    docker network rm "${p}net" >/dev/null 2>&1 || true
    docker volume rm "${p}home" >/dev/null 2>&1 || true
    docker image rm "${p}classic:1" "${p}buildkit:1" "${p}compose-t" >/dev/null 2>&1 || true
}
# Leftovers of an aborted earlier run
remove_test_objects

work=$(mktemp -d)
cleanup() {
    remove_test_objects
    rm -rf "$work"
}
trap cleanup EXIT

step() { printf '\n=== %s\n' "$*"; }
fail() {
    echo "FAILED: $*" >&2
    docker logs --tail 50 "${p}jenkins" >&2 || true
    exit 1
}
# Runs a command in the Jenkins container as user jenkins
as_jenkins() { docker exec -u jenkins "${p}jenkins" bash -c "$1"; }

step "Prepare JENKINS_HOME with files owned by root"
docker volume create "${p}home" >/dev/null
docker run --rm --entrypoint bash -v "${p}home:/var/jenkins_home" "$image" \
    -c 'mkdir -p /var/jenkins_home/root-dir && touch /var/jenkins_home/root-dir/file && chown -R 0:0 /var/jenkins_home'

step "Start alpinedockersocat and Jenkins"
docker network create "${p}net" >/dev/null
docker run -d --name "${p}dockersocat" --network "${p}net" \
    -v /var/run/docker.sock:/var/run/docker.sock "$socat_image" >/dev/null
# The quotes in JENKINS_OPTS are on purpose: compose files often contain
# them, jenkins.sh and the health check have to remove them
docker run -d --name "${p}jenkins" --network "${p}net" \
    -e DOCKER_HOST="tcp://${p}dockersocat:2375" \
    -e JAVA_OPTS=-Djenkins.install.runSetupWizard=false \
    -e "JENKINS_OPTS='--prefix=/jenkins'" \
    -p "127.0.0.1:$port:8080" -v "${p}home:/var/jenkins_home" "$image" >/dev/null

step "Wait until Jenkins is healthy"
health=
for _ in $(seq 1 100); do
    health=$(docker inspect -f '{{.State.Health.Status}}' "${p}jenkins")
    [ "$health" = healthy ] && break
    [ "$(docker inspect -f '{{.State.Running}}' "${p}jenkins")" = true ] || fail "container stopped"
    sleep 3
done
echo "health: $health"
[ "$health" = healthy ] || fail "not healthy"
curl -fsS -o /dev/null "$url/login" || fail "no answer on $url/login"

step "Ownership of JENKINS_HOME"
owners=$(docker exec "${p}jenkins" find /var/jenkins_home ! \( -user jenkins -group jenkins \) -print)
[ -z "$owners" ] || fail "not owned by jenkins: $owners"
echo "all files belong to jenkins"

step "Process tree and environment of Jenkins"
docker exec "${p}jenkins" ps -eo pid,ppid,user,args --cols 120
java_pid=$(docker exec "${p}jenkins" ps -eo pid=,ppid=,user=,comm= |
    awk '$2 == 1 && $3 == "jenkins" && $4 == "java" {print $1}')
[ -n "$java_pid" ] || fail "java is not a child of PID 1 running as jenkins"
java_env=$(docker exec -u jenkins "${p}jenkins" cat "/proc/$java_pid/environ" | tr '\0' '\n')
for v in HOME=/var/jenkins_home USER=jenkins LOGNAME=jenkins "DOCKER_HOST=tcp://${p}dockersocat:2375"; do
    grep -qxF "$v" <<<"$java_env" || fail "Jenkins environment lacks $v"
done
echo "java (PID $java_pid) runs as jenkins below tini, HOME=/var/jenkins_home"

step "Docker through socat as user jenkins"
as_jenkins 'docker version --format "client {{.Client.Version}}, server {{.Server.Version}}"'
as_jenkins 'docker compose version && docker-compose version && docker buildx version'
as_jenkins 'docker run --rm alpine:latest echo docker-run-ok' | grep -x docker-run-ok >/dev/null || fail "docker run"
echo "docker run ok"

step "docker build (classic builder and BuildKit)"
as_jenkins "mkdir -p /tmp/build && printf 'FROM alpine:latest\nRUN echo built > /built\n' > /tmp/build/Dockerfile"
as_jenkins "docker build -q -t ${p}classic:1 /tmp/build" >/dev/null || fail "docker build (classic)"
as_jenkins "DOCKER_BUILDKIT=1 docker build -q -t ${p}buildkit:1 /tmp/build" >/dev/null || fail "docker build (BuildKit)"
as_jenkins "docker run --rm ${p}buildkit:1 cat /built" | grep -x built >/dev/null || fail "built image"
echo "classic builder and BuildKit ok"

step "docker compose build, up and down"
as_jenkins "mkdir -p /tmp/compose && cp /tmp/build/Dockerfile /tmp/compose/ && printf 'services:\n  t:\n    build: .\n    image: ${p}compose-t\n    command: cat /built\n' > /tmp/compose/compose.yml"
as_jenkins "cd /tmp/compose && docker compose -p ${p}compose build -q && docker compose -p ${p}compose up --abort-on-container-exit" |
    grep built >/dev/null || fail "docker compose"
as_jenkins "cd /tmp/compose && docker compose -p ${p}compose down" >/dev/null 2>&1 || fail "docker compose down"
echo "docker compose ok"

step "Freestyle job with Docker commands"
cookies=$work/cookies
crumb=$(curl -fsS -c "$cookies" -b "$cookies" "$url/crumbIssuer/api/json" | sed 's/.*"crumb":"\([^"]*\)".*/\1/')
cat > "$work/job.xml" <<'XML'
<?xml version='1.1' encoding='UTF-8'?>
<project><builders><hudson.tasks.Shell><command>echo "HOME=$HOME"
docker run --rm alpine:latest echo job-run-ok
</command></hudson.tasks.Shell></builders></project>
XML
curl -fsS -c "$cookies" -b "$cookies" -H "Jenkins-Crumb: $crumb" -H 'Content-Type: application/xml' \
    --data-binary "@$work/job.xml" "$url/createItem?name=smoke" || fail "create job"
curl -fsS -c "$cookies" -b "$cookies" -H "Jenkins-Crumb: $crumb" -X POST "$url/job/smoke/build" || fail "start job"
result=
for _ in $(seq 1 60); do
    result=$(curl -fsS "$url/job/smoke/1/api/json" 2>/dev/null | sed -n 's/.*"result":"\([A-Z]*\)".*/\1/p') || true
    [ -n "$result" ] && break
    sleep 2
done
log=$(curl -fsS "$url/job/smoke/1/consoleText")
echo "$log"
[ "$result" = SUCCESS ] || fail "job result: $result"
grep -qx job-run-ok <<<"$log" || fail "job output"
grep -qx HOME=/var/jenkins_home <<<"$log" || fail "job HOME"

step "Clean shutdown with docker stop"
start=$(date +%s)
docker stop -t 120 "${p}jenkins" >/dev/null
echo "stopped after $(($(date +%s) - start))s, exit code $(docker inspect -f '{{.State.ExitCode}}' "${p}jenkins")"
docker logs --tail 5 "${p}jenkins" 2>&1
docker logs "${p}jenkins" 2>&1 | grep 'Jenkins stopped' >/dev/null || fail "no clean shutdown in the log"

printf '\nSmoke test passed\n'
