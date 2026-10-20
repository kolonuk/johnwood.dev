# TODO — johnwood.dev

Context as of 2026-10-20: the site was rewritten from the old 599-line
PHP/Apache resume page to a static Astro site (content lives in
`src/data/resume.json`). The contact form came back in a second pass: nginx
serves the static site, php-fpm handles just `php/contact.php`, which sends
mail via msmtp -> Gmail SMTP — same relay and app password the old site
used, just a small dedicated script instead of the inline 599-line template.
reCAPTCHA was dropped (its secret was already compromised in git history,
and the service is being phased out) for a simple honeypot field instead. A
Cloudflare Worker + Turnstile + Resend/Cloudflare-Email-Sending contact form
was attempted first and abandoned before deploying anything — repeatedly
blocked on plan/account constraints (Workers Paid, token permissions) each
time the approach changed. The image is built by
`.github/workflows/docker-build-push.yml`, published to
`ghcr.io/kolonuk/johnwood.dev`, and pulled by the dadock compose stack.

Previous TODO items about PHP warnings, jQuery, reCAPTCHA secrets and
image-size-from-PHP-base no longer apply — that code is gone. Image is
~137 MB (`php:8.2-fpm-alpine` + nginx, two processes in one container) —
still well down from the original 755 MB, though bigger than the brief
mailto-only, PHP-free ~90 MB version.

---

## Publishing

johnwood.dev is live (verified 2026-10-19) — published publicly via the
Pangolin tunnel + VPS, `Host()`-routed to this container. dadock *also* keeps
a LAN-only alias at `http://192.168.33.11/johnwood/` (`PathPrefix(/johnwood)`
+ `stripprefix`, homepage dashboard links to both) — that's a deliberate
second route for local testing/access, not a stopgap waiting to be replaced.
Both routes hit the same static build; all asset references in
`src/` are relative (no leading `/`) specifically so one image serves
correctly under either mount. Keep it that way — don't reintroduce
root-absolute paths (`href="/x"`, `url('/x')`) without re-checking both
routes still resolve (see the Docker-based check in git history around
2026-10-19 for how to simulate the `/johnwood/` prefix locally).

### [P2] Decide whether the GHCR package stays private
It is private today, and the dadock host pulls it because `bootstrap.sh` logs
in to `ghcr.io` with `GH_PAT`. Either make the package public, or document the
login as a hard prerequisite in the dadock setup notes.

### [P3] `add-slash` redirect leaks the backend port and wrong scheme
`https://johnwood.dev/resume` (no trailing slash) 301s to
`http://johnwood.dev:8080/resume/` — wrong scheme and the container's
internal port, not `johnwood.dev`'s public one. That's dadock's shared
`add-slash` redirectregex middleware reconstructing the URL from headers it's
seeing through the Pangolin tunnel; worth checking `X-Forwarded-Proto`/`-Port`
handling there since it likely affects every `PathPrefix` service, not just
this one. Not a johnwood.dev-repo fix.

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
