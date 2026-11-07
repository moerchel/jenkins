#!/bin/bash
# Starts Jenkins as user jenkins. Jenkins replaces this script (exec), so it
# runs directly below tini, gets the stop signal and shuts down cleanly.
set -euo pipefail

: "${JENKINS_HOME:=/var/jenkins_home}"

if [ "$(id -u)" = 0 ]; then
    # Files in JENKINS_HOME that don't belong to jenkins (e.g. created as root
    # in a bind mount or by a container of a build) are handed over to
    # jenkins. Files that already belong to jenkins are not touched.
    if ! find "$JENKINS_HOME" \( ! -user jenkins -o ! -group jenkins \) -exec chown -h jenkins:jenkins {} +; then
        echo "WARNING: not all files in $JENKINS_HOME could be handed over to user jenkins" >&2
    fi

    # Environment of user jenkins (HOME is used e.g. for ~/.docker/config.json
    # and ~/.gitconfig)
    HOME=$(getent passwd jenkins | cut -d: -f6)
    export HOME USER=jenkins LOGNAME=jenkins
    exec setpriv --reuid=jenkins --regid=jenkins --init-groups -- /usr/local/bin/jenkins.sh "$@"
fi

# Started with --user: no ownership changes possible
exec /usr/local/bin/jenkins.sh "$@"
