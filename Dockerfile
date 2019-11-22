FROM jenkins/jenkins:2.190.3

USER root

ENV DOCKERVERSION=19.03.5
ENV DOCKERCOMPOSEVERSION=1.25.0

RUN /usr/bin/curl -fsSLO https://download.docker.com/linux/static/stable/x86_64/docker-${DOCKERVERSION}.tgz \
  && /bin/tar xzvf docker-${DOCKERVERSION}.tgz --strip 1 -C /usr/local/bin docker/docker \
  && /bin/rm docker-${DOCKERVERSION}.tgz \
  && /bin/chmod +x /usr/local/bin/docker
  
RUN /usr/bin/curl -fsSL https://github.com/docker/compose/releases/download/${DOCKERCOMPOSEVERSION}/docker-compose-`uname -s`-`uname -m` > /usr/local/bin/docker-compose \
  && /bin/chmod +x /usr/local/bin/docker-compose
  
ENTRYPOINT ["/sbin/tini", "--"]

CMD /bin/chown -R 1000:1000 /var/jenkins_home \
  && /sbin/runuser -u jenkins -- /usr/local/bin/jenkins.sh
