#!/bin/bash
# Lists the software versions of an image as "name<TAB>version", sorted:
# all Debian packages plus Jenkins, Java and git-lfs, which don't come from
# Debian packages. Used to decide whether the weekly rebuild brings updates.
set -euo pipefail

image=$1

# ${Package} and ${Version} are dpkg-query fields, the second command runs in
# the container; neither are variables of this script
# shellcheck disable=SC2016
{
    docker run --rm --platform linux/amd64 --entrypoint dpkg-query "$image" \
        -W -f='${Package}\t${Version}\n'
    docker run --rm --platform linux/amd64 --entrypoint bash "$image" -c '
        printf "jenkins.war\t%s\n" "$JENKINS_VERSION"
        printf "java\t%s\n" "$(java -XshowSettings:properties -version 2>&1 | sed -n "s/^ *java.runtime.version = //p")"
        printf "git-lfs\t%s\n" "$(git-lfs version | sed "s,^git-lfs/,,; s, .*,,")"'
} | sort
