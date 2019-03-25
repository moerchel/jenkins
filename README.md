![Jenkins](https://raw.githubusercontent.com/docker-library/docs/3ab4dafb41dd0e959ff9322b3c50af2519af6d85/jenkins/logo.png)

The Jenkins Continuous Integration and Delivery server.

This is a fully functional [Jenkins](http://jenkins.io/) server, based on the Long Term Support release (2.164.1) including [Docker CLI](https://download.docker.com/linux/static/stable/x86_64/) (18.09.3) and [docker-compose](https://github.com/docker/compose/releases) (1.23.2).

## How to use this image
Here is the code for a *docker-compose.yml* file:

~~~~
version: '3.7'

services:

  jenkins:
    image: moerchel/jenkins
    ports:
      - "8080:8080"
      - "50000:50000"
    volumes:
      - jenkins_home:/var/jenkins_home
      - /var/run/docker.sock:/var/run/docker.sock
    restart: unless-stopped

volumes:
  jenkins_home:
        driver: local
~~~~
