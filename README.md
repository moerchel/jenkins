![Jenkins](https://raw.githubusercontent.com/docker-library/docs/3ab4dafb41dd0e959ff9322b3c50af2519af6d85/jenkins/logo.png)

The Jenkins Continuous Integration and Delivery server.

This is a fully functional [Jenkins](http://jenkins.io/) server, based on the Long Term Support release (2.235.5) including [Docker CLI](https://download.docker.com/linux/static/stable/x86_64/) (19.03.9) and [docker-compose](https://github.com/docker/compose/releases) (1.26.2).

## How to use this image
Here is the code for a *docker-compose.yml* file:

~~~~
version: '3.7'

services:

  jenkins:
    image: moerchel/jenkins
    container_name: jenkins
    environment:
      - DOCKER_HOST=tcp://dockersock:2375
    depends_on:
      - dockersock
    ports:
      - "8080:8080"
      - "50000:50000"
    volumes:
      - jenkins_home:/var/jenkins_home
    networks:
      - jenkins_net
    restart: unless-stopped

  dockersock:
    image: moerchel/dockersocat
    container_name: dockersocat
    userns_mode: "host"
    privileged: true
    expose:
      - "2375"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    networks:
      - jenkins_net
    restart: unless-stopped

volumes:
  jenkins_home:
        driver: local

networks:
  jenkins_net:
    name: jenkins_net
    driver: bridge
~~~~
