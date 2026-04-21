# `node` and `npm` installed
FROM diamol/node:2e AS builder

# create working dir for this image
WORKDIR /src
# `package.json` describe dependencies
COPY src/package.json .
# download dependencies
RUN npm install

# app
FROM diamol/node:2e

EXPOSE 80
# startup command
CMD ["node", "server.js"]

# create working dir for this image
WORKDIR /app
# copy dependencies from the builder image
COPY --from=builder /src/node_modules/ /app/node_modules/
# copy source code from host computer, since javascript is an interpreted language
COPY src/ .
