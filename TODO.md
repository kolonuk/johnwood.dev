# TODO — johnwood.dev

Context as of 2026-10-19: the site was rewritten from the PHP/Apache resume
page to a static Astro site (Markdown-free, content lives in
`src/data/resume.json`). The contact form, msmtp relay and reCAPTCHA were
dropped entirely — contact is a `mailto:` link. The image is built by
`.github/workflows/docker-build-push.yml`, published to
`ghcr.io/kolonuk/johnwood.dev`, and pulled by the dadock compose stack.

Previous TODO items about PHP warnings, the contact form, msmtp, jQuery,
reCAPTCHA secrets and image-size-from-PHP-base no longer apply — that code is
gone. New image is ~90 MB (`nginx-unprivileged:alpine` + static output),
down from 755 MB.

---

## Publishing

### [P1] johnwood.dev does not yet resolve to the new home
DNS lives in Cloudflare (zone `cbcb167f83363a3ee047318a5c1dee65`) but the
registrar still delegates to `ns1/ns2.kolonsolutions.co.uk` on the old VPS,
and the A record still points at `45.137.151.109`. Outstanding:

- Flip the Spaceship nameservers to `dilbert`/`kenia.ns.cloudflare.com`.
  Credentials are on the dadock host in `/srv/dadock/stack/.env` as
  `SPACESHIP_API_KEY` / `SPACESHIP_API_SECRET`; the call is
  `PUT https://spaceship.dev/api/v1/domains/johnwood.dev/nameservers`.
- Stand up the Pangolin tunnel so traffic reaches the home server, and add
  the `newt` client to the dadock stack.
- Repoint the A record at the VPS once the tunnel is up.

### [P2] Decide whether the GHCR package stays private
It is private today, and the dadock host pulls it because `bootstrap.sh` logs
in to `ghcr.io` with `GH_PAT`. Either make the package public, or document the
login as a hard prerequisite in the dadock setup notes.

### [P3] The `/johnwood` path prefix is temporary
Once the site is served at its own hostname, the `PathPrefix(/johnwood)` +
`stripprefix` routing in dadock should become a `Host()` rule.

---

## Content

### [P2] Fill in real contact details / profile links beyond DockerHub
`src/data/resume.json` only lists DockerHub as a profile. Add LinkedIn/GitHub
if wanted.

### [P3] Add an og:image / social preview card
Nothing in `<head>` sets Open Graph tags yet.

---

## GitHub Actions

### [P3] Enable Dependabot for GitHub Actions and npm
Nothing tells you when a pinned action or an npm dependency has a security
update. Add `.github/dependabot.yml`.

### [P3] No image signing or provenance
Consider cosign signatures and SBOM generation.

---

## Updating the CV

Edit `src/data/resume.json` (JSON Resume schema) — it is the single source
for both the web page (`/`) and the generated PDF (`/resume.pdf`, rendered
from `/resume` at build time). No other file needs to change for new work
history, skills or projects.
