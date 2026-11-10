FROM docker:27-cli

RUN apk add --no-cache curl git perl

COPY local-bootstrap.sh /usr/local/bin/local-bootstrap

RUN chmod +x /usr/local/bin/local-bootstrap
