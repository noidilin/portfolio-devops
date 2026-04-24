# golang tools installed
FROM diamol/golang:2e AS builder

# copy source code
COPY go.mod main.go /go/
# build directly, since this app doesn't have any dependencies to install
RUN go build -o /server

# app stage use minimal image containing only small layer of OS tools
FROM diamol/base:2e
ENV IMAGE_API_URL="http://iotd/image" \
  ACCESS_API_URL="http://accesslog/access-log"

CMD ["/web/server"]

# create workind directory in image
WORKDIR /web
# the HTML file served by server
COPY index.html .
# the binaries we built from previous stage
COPY --from=builder /server .
# binaries need to be explicitly marked as executable in linux
RUN chmod +x server
