# jenkis version 2.150.2
FROM jenkins/jenkins:lts

USER root

ENV DOCKERVERSION=18.09.1
ENV DOCKERCOMPOSEVERSION=1.23.2

RUN curl -fsSLO https://download.docker.com/linux/static/stable/x86_64/docker-${DOCKERVERSION}.tgz \
  && tar xzvf docker-${DOCKERVERSION}.tgz --strip 1 -C /usr/local/bin docker/docker \
  && rm docker-${DOCKERVERSION}.tgz \
  && chmod +x /usr/local/bin/docker
  
RUN curl -fsSL https://github.com/docker/compose/releases/download/${DOCKERCOMPOSEVERSION}/docker-compose-`uname -s`-`uname -m` > /usr/local/bin/docker-compose \
  && chmod +x /usr/local/bin/docker-compose

#CMD DOCKER_GID=$(stat -c '%g' /var/run/docker.sock) && \
#  groupadd -for -g ${DOCKER_GID} docker && \
#  usermod -aG docker jenkins && \
#  chown -R 1000:1000 /var/jenkins_home && \
#  su -c "/usr/local/bin/jenkins.sh" jenkins
  
CMD chown -R 1000:1000 /var/jenkins_home && \
  su -c "/usr/local/bin/jenkins.sh" jenkins
