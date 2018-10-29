<p><img src="https://raw.githubusercontent.com/docker-library/docs/3ab4dafb41dd0e959ff9322b3c50af2519af6d85/jenkins/logo.png"></p>
The Jenkins Continuous Integration and Delivery server.

This is a fully functional <a href="http://jenkins.io/">Jenkins</a> server, based on the Long Term Support release including <a href="https://download.docker.com/linux/static/stable/x86_64/">Docker CLI</a> (18.06.1-ce) and <a href="https://github.com/docker/compose/releases/download/">docker-compose</a> (1.22.0).

<h1>How to use this image</h1>
Here is the code for a <code>docker-compose.yml</code> file:
<pre><code>
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
</code></pre>
