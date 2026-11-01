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
docker run -p 8080:8080 \
  -e SMTP_USER=you@gmail.com -e SMTP_PASSWORD=app-password \
  johnwood.dev
```

Multi-stage build: Node compiles the site and renders the CV PDF with
Chromium (build stage only). The final image runs nginx for the static output
on port 8080, plus php-fpm for `/contact.php`, which sends mail via msmtp over
Gmail SMTP using `SMTP_USER`/`SMTP_PASSWORD` (optional `SMTP_FROM`, defaults
to `SMTP_USER`). Without them the entrypoint logs a warning and the contact
form silently fails to send.

CI (`.github/workflows/docker-build-push.yml`) builds, smoke-tests and scans
the image with Trivy before pushing to `ghcr.io/kolonuk/johnwood.dev`; the
dadock compose stack on the home server pulls it from there — this repo does
not deploy by itself. See `TODO.md` for outstanding work.
