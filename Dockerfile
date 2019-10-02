#### Run the build on alpine - istiod doesn't need more.
# Main docker images for istiod will be distroless and alpine.
FROM golang:1.13-alpine AS build

RUN apk add --no-cache git && pwd && ls
COPY . .
# Runs in /go directory
RUN GOPROXY=https://proxy.golang.org GO111MODULE=on CGO_ENABLED=0 GOOS=linux \
  GOPATH="" go build -a -ldflags '-extldflags "-static"' -o istiod-vm ./cmd/istiod-vm
RUN GOPROXY=https://proxy.golang.org GO111MODULE=on CGO_ENABLED=0 GOOS=linux \
  GOPATH="" go build -a -ldflags '-extldflags "-static"' -o istiod ./cmd/istiod && ls

#### Fortio - used for the tests
FROM fortio/fortio:latest AS fortio

### Container for testing for Istio VM deb files, in ubuntu container
## Will include hyperistio (the minimal, non-k8s version), fortio for testing, other tools needed for debugging.
## Will install envoy from the official release .deb ( but not using the systemd unit for start )
FROM ubuntu:bionic AS sidecar-test

RUN apt-get update &&\
    apt-get install -y curl iptables iproute2 &&\
    curl  https://storage.googleapis.com/istio-release/releases/1.3.0-rc.0/deb/istio-sidecar.deb -o /tmp/istio.deb &&\
    dpkg -i /tmp/istio.deb
COPY --from=build /go/istiod-vm /usr/local/bin/istiod-vm
COPY --from=fortio /usr/share/fortio /usr/share/fortio
COPY --from=fortio /usr/bin/fortio /usr/bin/fortio
EXPOSE 8079
EXPOSE 8080
EXPOSE 8081

### Container running the combined control plane, with an alpine base ( smaller than distroless but with shell )
### TODO: add a distroless variant.
### This image should work as a drop-in replacement for Pilot, Galley(MCP portion), WebhookInjector
### Citadel, Gallye/Validation remain as separate deployments.
FROM envoyproxy/envoy-alpine AS istio-control

COPY --from=build /go/istiod /usr/local/bin/istiod

WORKDIR /
ENTRYPOINT /usr/local/bin/istiod
