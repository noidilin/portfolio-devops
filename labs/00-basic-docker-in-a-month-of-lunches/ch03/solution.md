# Solution

The `Dockerfile` and the `ch03.txt` file are presented here for reference.

## Steps

- spin up the lab container from image `diamol/ch03-lab:2e` (in interactive mode as the hint suggested)

`docker container run -it --name ch03lab diamol/cho03-lab:2e`

- append name at the end of the `ch03.txt` file (in container shell session)

`echo "John Doe" >> ch03.txt`

- Here is the tricky part. We need to build an image based on the modification we made in the ephemeral layer.
  - Docker stop the container when there is no process running inside that container.
  - The file system still exist unless the container is being terminated.
  - we can use `docker container commit` to create new image from container's changes

`docker container commit ch03lab ch03-lab-soln:2e`

- spin up a new container based on the newly created image to see if the change persist

`docker container run ch03-lab-soln:2e cat ch03.txt`
