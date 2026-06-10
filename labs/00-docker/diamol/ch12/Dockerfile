# NOTE: base image needs to support multi-platform
# FROM diamol/base:2e-linux-amd64
FROM diamol/base:2e

# NOTE: clean up commands to be platform-agnostic
# RUN mkdir -p /logs && \
#   cd /logs && \
#   echo 1 > init.txt
WORKDIR /logs
RUN echo 1 > init.txt

RUN echo 2 >> /logs/init.txt

# NOTE: clean up command to be platform-agnostic
# CMD head /logs/init.txt
CMD [ "cat", "init.txt" ]
