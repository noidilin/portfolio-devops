# Solution

## Be care of the current working directory

When writing a Dockerfile, always ask:

1. which stage am I in?
2. what is the current WORKDIR in this stage?
3. is this path from host, from another stage, or inside this image?
4. is this path absolute or relative?

Every new stage reset the cwd.

- `FROM`: new container
- `WORKDIR`: cd
- `COPY`: move files into the current container
- `RUN`: execute commands in current container
