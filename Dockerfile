FROM jenkins/jenkins:2.541.1-jdk21

USER root

ENV DOCKERVERSION=29.2.1
ENV DOCKERCOMPOSEVERSION=5.0.2

RUN /usr/bin/curl -fsSLO https://download.docker.com/linux/static/stable/x86_64/docker-${DOCKERVERSION}.tgz \
  && /bin/tar xzvf docker-${DOCKERVERSION}.tgz --strip 1 -C /usr/local/bin docker/docker \
  && /bin/rm docker-${DOCKERVERSION}.tgz \
  && /bin/chmod +x /usr/local/bin/docker \
  && /bin/mkdir -p /usr/local/lib/docker/cli-plugins

RUN /usr/bin/curl -fsSL https://github.com/docker/compose/releases/download/v${DOCKERCOMPOSEVERSION}/docker-compose-`uname -s`-`uname -m` > /usr/local/lib/docker/cli-plugins/docker-compose \
  && /bin/chmod +x /usr/local/lib/docker/cli-plugins/docker-compose \
  && /bin/ln -s /usr/local/lib/docker/cli-plugins/docker-compose /usr/local/bin/docker-compose

ENTRYPOINT ["/usr/bin/tini", "--"]

CMD /bin/chown -R 1000:1000 /var/jenkins_home \
  && /sbin/runuser -u jenkins -- /usr/local/bin/jenkins.sh
