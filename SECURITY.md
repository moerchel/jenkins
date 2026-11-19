# Security policy

## Supported versions

Only the newest image is supported: `latest` and the newest release tag.
Older release tags are not updated. The image is rebuilt every 3 days
with the current Debian packages and Docker tools. Dependabot proposes
new Jenkins LTS releases at its next weekly check.

## Reporting a vulnerability

Please don't open a public issue. Report it privately via
**Security → Report a vulnerability** in this repository.

## Scope

In scope: the Dockerfile, entrypoint.sh, healthcheck.sh and the GitHub
workflows of this repository.

Vulnerabilities in Jenkins or its plugins should be reported to the
Jenkins security team (https://www.jenkins.io/security/reporting/),
vulnerabilities in the Docker tools to Docker
(https://www.docker.com/trust/vulnerability-disclosure-policy/) and in
Debian packages to Debian (https://www.debian.org/security/). Their fixes
reach this image with the next rebuild or Jenkins LTS update. Plugins are
not part of the image, they are updated in Jenkins itself.
