# johnwood.dev

Static CV/resume site built with [Astro](https://astro.build). Content lives
in one file, `src/data/resume.json` (JSON Resume schema) — edit that to
update work history, education, skills or projects; both the web page and
the generated PDF read from it.

## Develop

```sh
npm install
npm run dev
```

## Build

```sh
npm run build   # -> dist/
npm run pdf     # renders dist/resume/index.html -> dist/resume.pdf (needs Chromium; see Dockerfile)
```

## Container

```sh
docker build -t johnwood.dev .
docker run -p 8080:8080 johnwood.dev
```

Multi-stage build: `node:22-alpine` compiles the site and renders the CV PDF
with Chromium (installed only in the build stage), then the static output is
served by `nginxinc/nginx-unprivileged:alpine` on port 8080 as a non-root
user. Final image is ~90 MB.

CI (`.github/workflows/docker-build-push.yml`) builds, smoke-tests and scans
the image with Trivy before pushing to `ghcr.io/kolonuk/johnwood.dev`; the
dadock compose stack on the home server pulls it from there — this repo does
not deploy by itself. See `TODO.md` for outstanding work.
