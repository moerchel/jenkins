![Jenkins](https://raw.githubusercontent.com/docker-library/docs/3ab4dafb41dd0e959ff9322b3c50af2519af6d85/jenkins/logo.png)

The Jenkins Continuous Integration and Delivery server.

This is a fully functional [Jenkins](http://jenkins.io/) server, based on the Long Term Support release (2.462.1) including [Docker CLI](https://download.docker.com/linux/static/stable/x86_64/) (27.1.2) and [docker-compose](https://github.com/docker/compose/releases) (2.29.1).

## How to use this image

Here is the code for a simple _docker-compose.yml_ file:

```yml
version: "3"

services:
  jenkins:
    image: ghcr.io/moerchel/jenkins:master
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
    image: ghcr.io/moerchel/alpinedockersocat:main
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
```

Here is the code for a more advanced _docker-compose.yml_ file including docker registry and [traefik](https://doc.traefik.io/traefik/) labels:

```yml
version: "3"

services:
  jenkins:
    image: ghcr.io/moerchel/jenkins:master
    container_name: jenkins
    security_opt:
      - no-new-privileges:true
    environment:
      - DOCKER_HOST=tcp://dockersock:2375
      - JENKINS_OPTS='--prefix=/jenkins'
    depends_on:
      - dockersock
    volumes:
      - /path/to/jenkins:/var/jenkins_home
    networks:
      - jenkins
      - traefik
    restart: unless-stopped
    labels:
      - "traefik.enable=true"
      - "traefik.docker.network=traefik"
      - "traefik.http.routers.jenkins.entrypoints=websecure"
      - "traefik.http.routers.jenkins.rule=(Host(`example.org`) && PathPrefix(`/jenkins`))"
      - "traefik.http.routers.jenkins.tls=true"
      - "traefik.http.routers.jenkins.tls.certresolver=letsencrypt"
      - "traefik.http.services.jenkins.loadbalancer.server.port=8080"

  dockersock:
    image: ghcr.io/moerchel/alpinedockersocat:main
    container_name: dockersocat
    userns_mode: "host"
    privileged: true
    expose:
      - "2375"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    networks:
      - jenkins
    restart: unless-stopped

  registry:
    image: registry
    container_name: registry
    environment:
      - REGISTRY_STORAGE_DELETE_ENABLED=true
    ports:
      - "127.0.0.1:5000:5000"
    volumes:
      - /path/to/registry:/var/lib/registry
    networks:
      - jenkins
    restart: unless-stopped

networks:
  jenkins:
    name: jenkins
    external: true
  traefik:
    name: traefik
    external: true
```
