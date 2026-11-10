FROM docker:27-cli

RUN apk add --no-cache curl git perl

COPY local-bootstrap.sh /usr/local/bin/local-bootstrap
COPY publish-pulse-api.sh /usr/local/bin/publish-pulse-api

RUN chmod +x /usr/local/bin/local-bootstrap /usr/local/bin/publish-pulse-api
