FROM jenkins/jenkins:lts

USER root

ENV DOCKERVERSION=18.06.1-ce
ENV DOCKERCOMPOSEVERSION=1.22.0

RUN curl -fsSLO https://download.docker.com/linux/static/stable/x86_64/docker-${DOCKERVERSION}.tgz \
  && tar xzvf docker-${DOCKERVERSION}.tgz --strip 1 -C /usr/local/bin docker/docker \
  && rm docker-${DOCKERVERSION}.tgz \
  && chmod +x /usr/local/bin/docker
  
RUN curl -L https://github.com/docker/compose/releases/download/${DOCKERCOMPOSEVERSION}/docker-compose-`uname -s`-`uname -m` > /usr/local/bin/docker-compose \
  && chmod +x /usr/local/bin/docker-compose

CMD DOCKER_GID=$(stat -c '%g' /var/run/docker.sock) && \
    groupadd -for -g ${DOCKER_GID} docker && \
    usermod -aG docker jenkins && \
    su -c "/usr/local/bin/jenkins.sh" jenkins

