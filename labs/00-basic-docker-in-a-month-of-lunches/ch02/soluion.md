# Solution

By observing the Dockerfile, we can know where the served html file is located. Replace the target file with our desired content can pass this lab.

## Steps

1. spin up the container with `docker container run --detach --publish 8088:80 diamol/ch02-hello-diamol-web:2e`
2. look into the Dockerfile to see the file destination `COPY html/ /usr/local/apache2/htdocs/`
3. copy the new index file to the destination directory `docker container cp index.html {docker-id}:/usr/local/apache2/htdocs/index.html`
4. check the end point `http://localhost:8088`
