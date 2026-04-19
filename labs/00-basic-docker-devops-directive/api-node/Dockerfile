FROM node:19.6-alpine

# specify working dir other than `/`
WORKDIR /usr/src/app
# copy only necessary file for installing depencencies (lean layer caching)
COPY package*.json ./

ENV NODE_ENV=production
# clean install without dev dependencies
RUN npm ci --only=production

# avoid using root user for security reason
USER node
# copy remaining source code afte installing depencencies
COPY --chown=node:node ./src .

# indicate the desired port
EXPOSE 3000
# production style container entrypoint
CMD [ "node", "index.js" ]
