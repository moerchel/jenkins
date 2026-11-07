#!/bin/bash
# Healthy as soon as Jenkins is fully started: /login answers with 200,
# during startup Jenkins answers with 503. Port and path prefix are taken
# from JENKINS_OPTS (--httpPort=..., --prefix=...).
set -euo pipefail

port=8080
prefix=

# JENKINS_OPTS is split like in jenkins.sh, quotes are removed by xargs
while IFS= read -r -d '' opt; do
    case $opt in
        --httpPort=*) port=${opt#*=} ;;
        --prefix=*) prefix=${opt#*=} ;;
    esac
done < <([[ -n ${JENKINS_OPTS:-} ]] && xargs printf '%s\0' <<<"$JENKINS_OPTS")

# "/jenkins", "jenkins/" and "/" are all accepted
prefix=/${prefix#/}
prefix=${prefix%/}

exec curl -fsS -o /dev/null --max-time 8 "http://127.0.0.1:${port}${prefix}/login"
