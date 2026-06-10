# contains `maven` build tool and `openjdk` runtime
FROM diamol/maven:2e AS builder

# create a working dir for this image
WORKDIR /usr/src/iotd
# `pom.xml` is the Maven definition of the Java build
COPY pom.xml .
# fetch dependencies
RUN mvn -B dependency:go-offline

# copy files from where `docker build` is executing into the working dir in the image
COPY . .
# compile and package the app
RUN mvn package

# docker only go on to build the next part if previous stage complete without error
# PERF: the application image don't need build tool `maven`
# If I run an interactive container from this new image, there won't be `mvn` command there
FROM diamol/openjdk:2e

# create a working dir for this image
WORKDIR /app
# in the builder state, maven package application and all dependencies in this `.jar` file
COPY --from=builder /usr/src/iotd/target/iotd-service-0.1.0.jar .

EXPOSE 80
# execute java runtime at this entry point when a container start from the image
ENTRYPOINT ["java", "-jar", "/app/iotd-service-0.1.0.jar"]
