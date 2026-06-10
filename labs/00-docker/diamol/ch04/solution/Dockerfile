# builder
FROM diamol/golang:2e AS builder

COPY go.mod main.go /go/
RUN go build -o /server

# app
FROM diamol/base:2e

EXPOSE 80
ENV USER=sixeyed

# the path should match where we copy files to
CMD ["/web/server"]

# `.` means /web from now on
WORKDIR /web
# copied from builder image /server to /web/server
COPY --from=builder /server .
# copied from host index.html to /web/index.html
COPY index.html .
RUN chmod +x /web/server

