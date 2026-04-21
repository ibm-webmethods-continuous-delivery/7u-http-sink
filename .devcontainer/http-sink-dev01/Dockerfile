ARG __alpine_version=3.23
FROM alpine:${__alpine_version}

ARG __golang_ci_version=v2.11.0

ARG __gid=1001
ARG __gname=dev
ARG __uid=1001
ARG __uname=dev
ARG __user_home=/home/${__uname}

ENV GOROOT=/usr/lib/go
ENV GOPATH=/opt/go
ENV PATH=${GOPATH}/bin:$PATH

RUN apk update --no-cache \
    && apk upgrade --no-cache \
    && apk add --no-cache \
      curl \
      git \
      go \
      make \
      mandoc \
      musl-dev \
      shellcheck \
      shunit2 \
      zip \
    && mkdir -p ${GOPATH}/src ${GOPATH}/bin \
    && wget -O- -nv https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | sh -s ${__golang_ci_version} \
    && addgroup -g ${__gid} ${__gname} \
    && adduser -u ${__uid} -G ${__gname} -D -h ${__user_home} ${__uname} \
    && chown -R ${__uname}:${__gname} ${GOPATH}

HEALTHCHECK CMD exit 0

USER ${__uname}
