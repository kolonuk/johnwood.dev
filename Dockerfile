# Build stage: compile the Astro site to static HTML, then render the CV
# page to a PDF with Chromium (installed here only, not shipped in the final
# image).
FROM node:22-alpine AS build

# hadolint ignore=DL3018
# Pinned Alpine package versions leave the current apk index on the next
# base image update and break the build; apk add --no-cache already pulls
# whatever is current and current gets rebuilt on every push anyway.
RUN apk add --no-cache chromium
ENV CHROMIUM_PATH=/usr/bin/chromium-browser

WORKDIR /app
COPY package.json package-lock.json* ./
RUN npm install

COPY astro.config.mjs tsconfig.json ./
COPY public ./public
COPY src ./src
COPY scripts ./scripts

RUN npm run build && npm run pdf

# Serve stage: static files only, unprivileged nginx on 8080 (no root needed
# to bind the port, same convention as the previous PHP image).
FROM nginxinc/nginx-unprivileged:alpine AS serve

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/dist /usr/share/nginx/html

EXPOSE 8080
