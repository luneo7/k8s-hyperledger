FROM node:6-alpine

# Reset npm logging to default level.
ENV NPM_CONFIG_LOGLEVEL warn

# Install the latest version by default.
ARG VERSION=latest

# Need to install extra dependencies for native modules.
RUN apk add --no-cache make gcc g++ python git libc6-compat && \
    npm install --production -g pm2 composer-rest-server@0.13.2 && \
    npm cache clean --force && \
    apk del make gcc g++ python git

# Remove yarn
RUN rm -r /opt/yarn && \
    rm /usr/local/bin/yarn /usr/local/bin/yarnpkg

# Config maximum payload
RUN sed -i -e 's/100kb/1mb/g' /usr/local/lib/node_modules/composer-rest-server/server/config.json
RUN sed -i -e 's/"parse": {}/"parse": { "body-parser#json": { "params" : { "limit" : "1mb"}}, "body-parser#urlencoded": {"params": { "limit" : "1mb", "extended": true }} }/g' /usr/local/lib/node_modules/composer-rest-server/server/middleware.json

# Create the composer user ID.
RUN adduser -S composer

# Run as the composer user ID.
USER composer

# Run in the composer users home directory.
WORKDIR /home/composer

# Run supervisor to start the application.
CMD [ "pm2-docker", "composer-rest-server" ]

# Expose port 3000.
EXPOSE 3000
