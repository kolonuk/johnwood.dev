# TODO — johnwood.dev

Outstanding work on the containerised resume site (`src/`) and its build
pipeline. Findings are ordered by priority; each notes how it was verified.

Legend: **[P1]** blocking / actively exploitable · **[P2]** should fix ·
**[P3]** nice to have

Context as of 2026-10-17: the site has moved off the CentOS 7 VPS. The image
is built by `.github/workflows/docker-build-push.yml`, published to
`ghcr.io/kolonuk/johnwood.dev`, and pulled by the dadock compose stack, where
it is served at `http://192.168.33.11/johnwood/`. Public access over
`johnwood.dev` is not wired up yet — see "Publishing" below.

---

## Done (2026-10-17)

Kept here briefly so the history of the list is readable; delete once stale.

- Google App Engine and Artifact Registry deployment removed; the workflow
  publishes to GHCR using the per-run `GITHUB_TOKEN`.
- The `phpcs` PSR-12 gate is dropped (wrong standard for an HTML-first file);
  `php -l` remains.
- Build caching added via `docker/build-push-action` with `type=gha`.
- Workflow permissions narrowed to `contents: read`, with `packages: write`
  only on the build job.
- `apt-get upgrade` added to the image so Debian security patches land on
  every rebuild. Trivy went from three HIGH curl CVEs to zero.
- `js/scripts.js`, `resume.json` and `scss/styles.scss` recovered from the old
  server into the repo as build sources, excluded from the image.

---

## Blocking

### [P1] PHP warnings and file paths are rendered to every visitor
Still live. Verified 2026-10-17 against the deployed container:

```
$ curl -s http://192.168.33.11/johnwood/ | grep Warning
<b>Warning</b>:  Undefined array key "from_email" in <b>/var/www/html/index.php</b> on line <b>503</b><br />
<b>Warning</b>:  Undefined array key "message" in <b>/var/www/html/index.php</b> on line <b>504</b><br />
<b>Deprecated</b>:  Constant FILTER_SANITIZE_STRING is deprecated in <b>/var/www/html/index.php</b> on line <b>504</b><br />
<b>Warning</b>:  Undefined array key "uniquecapture" in <b>/var/www/html/index.php</b> on line <b>506</b><br />
```

`php -i` in the container confirms the cause: `Loaded Configuration File =>
(none)` and `display_errors => STDOUT`. The image ships no `php.ini`, so PHP
falls back to developer defaults. This leaks absolute paths and line numbers
and makes the page look broken. Two fixes, do both:

1. In `src/Dockerfile`, activate the production INI the base image already
   carries: `RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"`.
   That sets `display_errors=Off` and logs to stderr instead.
2. Fix the underlying bugs — `src/index.php:503-506` read `$_POST[...]` keys
   unconditionally, and `$recaptureMsg` (`:513`) is undefined on any GET
   request. Guard with `$_SERVER['REQUEST_METHOD'] === 'POST'` and use `??`
   defaults.

(1) alone only hides the problem; (2) alone still leaves developer error
display enabled in production.

### [P1] The image is pushed before it is scanned
`build` pushes both `:prod-<sha>` and `:latest`; `trivy-image-scan` runs
afterwards as a separate job. A vulnerable image is therefore in GHCR — with
`:latest` already pointing at it — before the gate meant to block it. This bit
today: the first green build pushed an image carrying three HIGH curl CVEs,
and the scan failed only after the push.

Restructure to: build locally (`load: true`) → scan → push on pass. Push
`:latest` only once every gate is green, so dadock tracking `:latest` can
never pull an image that failed its scan.

---

## Publishing

### [P1] johnwood.dev does not yet resolve to the new home
DNS now lives in Cloudflare (zone `cbcb167f83363a3ee047318a5c1dee65`) but the
registrar still delegates to `ns1/ns2.kolonsolutions.co.uk` on the old VPS, and
the A record still points at `45.137.151.109`. Outstanding:

- Flip the Spaceship nameservers to `dilbert`/`kenia.ns.cloudflare.com`.
  Credentials are on the dadock host in `/srv/dadock/stack/.env` as
  `SPACESHIP_API_KEY` / `SPACESHIP_API_SECRET`; the call is
  `PUT https://spaceship.dev/api/v1/domains/johnwood.dev/nameservers`.
- Stand up the Pangolin tunnel so traffic reaches the home server, and add
  the `newt` client to the dadock stack.
- Repoint the A record at the VPS once the tunnel is up.

### [P2] Decide whether the GHCR package stays private
It is private today, and the dadock host pulls it because `bootstrap.sh` logs
in to `ghcr.io` with `GH_PAT`. That works, but it means any new host needs
that PAT before it can pull. Either make the package public, or document the
login as a hard prerequisite in the dadock setup notes.

### [P3] The `/johnwood` path prefix is temporary
Once the site is served at its own hostname, the `PathPrefix(/johnwood)` +
`stripprefix` routing in dadock should become a `Host()` rule. The relative
asset paths in `index.php` work under both, so this is tidiness, not a bug.

---

## Image size — currently 755 MB

Up from 729 MB after the `apt-get upgrade` layer. For a site whose own content
is 414 kB, that is roughly 1800x overhead. Options, smallest change first:

### [P2] Drop the build-time dependencies from the final layer
`libonig-dev` and `libxml2-dev` are still installed in the shipped image
(verified: `dpkg -l` matches both). They are only needed while
`docker-php-ext-install` compiles `mbstring` and `xml`; the runtime needs
`libonig5` and `libxml2`, which the base already has. Remove them in the same
`RUN` layer after the extension build, or use a multi-stage build that copies
only the compiled `.so` files.

### [P2] Check whether `mbstring` and `xml` are needed at all
`index.php` is the only PHP file. If it uses neither extension, the whole
`apt-get install` plus `docker-php-ext-install` step disappears, taking
`libonig-dev`/`libxml2-dev` with it. Verify before removing.

### [P3] Move to an Alpine or FPM base
`php:8.2-apache` is ~500 MB before anything is added. `php:8.3-fpm-alpine`
behind a small nginx is on the order of 100 MB. Costs a slightly more involved
Dockerfile and a second process or container.

### [P3] Drop PHP entirely
The dynamic surface is one contact form. Move it to a Cloudflare Worker, a
hosted form service, or a small function, and the site becomes `nginx:alpine`
plus 414 kB — call it 50 MB. This also removes the PHP attack surface, the
SMTP credential handling in the image, and the mail-relay abuse risk in one
move. Biggest win, biggest change.

### [P3] Pin the base image by digest
`FROM php:8.2-apache` is a moving tag, so two builds of the same commit can
differ. Pin `php:8.2-apache@sha256:...` and bump it deliberately. Note this
interacts with the `apt-get upgrade` above — pinning the base makes the
upgrade layer the thing that moves, which is the right split.

### [P2] PHP 8.2 security support ends 2026-12-31
About ten weeks out. Move to 8.3 or 8.4. Test the contact form when you do:
`FILTER_SANITIZE_STRING` is already deprecated, and its removal is what turns
the output-escaping item below from theoretical into urgent.

---

## GitHub Actions changes needed

### [P1] `ubuntu-latest` migrates to Ubuntu 26 from 2026-10-19
Flagged as an annotation on every run — two days out. All five jobs use
`ubuntu-latest`. Pin to `ubuntu-24.04` now so the migration is a deliberate
change rather than a surprise failure, then bump when you have time to test.

### [P2] Node 20 actions are being force-run on Node 24
Also annotated on every run: `actions/checkout@11d5960` (v4) and
`actions/cache@0400d5f` (pulled in by `docker/build-push-action`) target Node
20, which is deprecated — the runner is already overriding them to Node 24.
Bump `actions/checkout` to v5. The cache action comes in transitively, so
bumping `docker/build-push-action` is the fix there.

### [P2] Pin the remaining actions to commit SHAs
`shivammathur/setup-php@v2`, `hadolint/hadolint-action@v3.1.0`,
`docker/setup-buildx-action@v3`, `docker/login-action@v3`,
`docker/build-push-action@v6` and `actions/delete-package-versions@v5` are on
mutable tags, while `actions/checkout` and `trivy-action` are SHA-pinned. The
mix gives the appearance of supply-chain hygiene without the guarantee — pin
all of them or none.

### [P2] Add a smoke test before pushing
Nothing in CI verifies the image serves traffic. Run the container, curl `/`,
require HTTP 200 and assert the body contains no `<b>Warning</b>`. That second
assertion would have caught the P1 above, and it is the natural companion to
the build-then-scan-then-push restructure.

### [P2] Verify the retention job does not delete the running image
`cleanup-images` uses `actions/delete-package-versions` with
`min-versions-to-keep: 5` and `ignore-versions-with-tags: latest`. It has not
yet run against more than five versions, so the keep window is untested. Check
it leaves the `prod-<sha>` tag dadock is pinned to alone before trusting it —
deleting an in-use tag would break the next `docker compose pull`.

### [P3] The Trivy filesystem scan can only ever pass
`trivy-fs` scans `src/` for vulnerable dependencies, but there are no
dependency manifests left — no `composer.json`, no `package.json`. It runs for
~30s and finds nothing by construction. Either drop it or repoint it at
`scan-type: config`.

### [P3] Delete the dead Google secrets
`WIF_PROVIDER` and `WIF_SERVICE_ACCOUNT` remain in the repository settings and
are no longer referenced by anything.

### [P3] Enable Dependabot for GitHub Actions
Nothing tells you when a pinned action has a security update. Add
`.github/dependabot.yml` with the `github-actions` ecosystem. This is also
what makes SHA-pinning maintainable rather than a thing that rots.

### [P3] No image signing or provenance
Consider cosign signatures and SBOM generation so what is running can be
verified.

---

## Security

### [P2] Rotate the committed reCAPTCHA secret
`src/index.php:484` has the secret key inline and it is in git history, so
changing the file is not enough — issue a new key pair in the reCAPTCHA admin
console and retire the old one. Then read it from the environment
(`getenv('RECAPTCHA_SECRET')`) and pass it to the container the way the SMTP
credentials already are. The site key on `:520` is public by design.

### [P2] Send the reCAPTCHA secret in a POST body, not a query string
`src/index.php:485` puts the secret in the URL of a GET request. URLs are
logged by proxies and surface in error messages. Switch to a cURL POST to
`https://www.google.com/recaptcha/api/siteverify` with the parameters in the
request body.

### [P2] The reCAPTCHA verification call has no timeout
`file_get_contents()` on `:485` uses `default_socket_timeout` (60s). A slow or
unreachable Google endpoint holds an Apache worker for a full minute per
request, making the contact form a cheap way to exhaust the worker pool. Use
cURL with an explicit `CURLOPT_TIMEOUT` of a few seconds and treat a failed
call as verification failure — which is what the current code does by
accident, via `json_decode(false) === null`.

### [P2] Output is never escaped
`$from_email`, `$message` and `$uniquecapture` are echoed back into the page
(`:510`, `:518-521`) relying solely on input filters. `FILTER_SANITIZE_STRING`
is deprecated and slated for removal; when it goes, `$message` and
`$uniquecapture` become raw reflected XSS. Escape on output with
`htmlspecialchars($v, ENT_QUOTES, 'UTF-8')` regardless of the input filter —
filter on input, escape on output, always both.

### [P2] No rate limiting on the contact form
`mail()` now relays through a real Gmail account, so an unthrottled form is a
route to getting that account flagged. reCAPTCHA raises the cost but does not
cap volume. Add a per-IP throttle, or move sending to an API with its own
quotas and abuse handling.

### [P2] jQuery 1.12.4 is loaded from a CDN
`src/index.php:595` pulls jQuery 1.12.4 (2016). Versions before 3.5.0 carry
known XSS issues (CVE-2020-11022, CVE-2020-11023). Upgrade to a current 3.x
and self-host it.

### [P3] Subresource Integrity is missing on most third-party assets
Four external `<script>`/`<link>` tags, one `integrity` attribute. Add SRI
hashes to the rest or self-host them — self-hosting also removes the
third-party requests the page makes on every load.

### [P3] No security response headers
No `Content-Security-Policy`, `X-Content-Type-Options`, `Referrer-Policy` or
`X-Frame-Options`. Add them in the image's Apache config or at Traefik —
decide which layer owns this so it is not set twice with conflicting values.

### [P3] SMTP credentials are reachable from PHP
`docker-entrypoint.sh` writes the Gmail app password to
`/var/www/msmtp/msmtprc` as `www-data`, the same user PHP runs as, so any
file-disclosure bug in PHP exposes it. Inherent to the msmtp approach and
acceptable for a scoped app password, but:

- Have the entrypoint `unset SMTP_PASSWORD` before `exec`, so the value is not
  left in the Apache process environment and visible via `/proc/*/environ` or
  `docker inspect`.
- Prefer mounting the credential as a file over passing it as an environment
  variable.

### [P3] Email header injection is only incidentally blocked
`src/index.php:529` concatenates user input into a `Reply-to:` header.
`FILTER_SANITIZE_EMAIL` happens to strip CR and LF, which is what stops header
injection today. Reject strings containing `\r` or `\n` explicitly rather than
relying on that side effect.

### [P3] No CSRF token on the contact form
reCAPTCHA partially covers this. Low impact for a form that only mails the
site owner, but worth adding if it ever does anything else.

---

## Content

### [P2] `resume.html` is broken and orphaned
It references `libs/twitter-bootstrap/3.2.0/` and `libs/octicons/2.0.2/`,
neither of which exists in the repo — and neither existed on the old server
either, so it has been broken in production for some time. It is not linked
from `index.php`. Either fix it, point it at CDN copies, or delete it along
with `resume.json`, which nothing references.

### [P3] The ATC directory was not carried over
229 MB of offline cadet training material under `ATC/` on the old server, with
`Options +Indexes` for browsing. It had zero hits in the entire access log and
was deliberately left behind. If it is still wanted, it belongs on a volume
(`${DATA_ROOT}`) rather than in the image. Otherwise it dies with the VPS.

---

## Documentation

### [P2] Write a README
`README.md` was deleted with the App Engine setup and nothing replaced it. It
should cover: what the image is, how to build and run it, the `SMTP_USER` /
`SMTP_PASSWORD` / `SMTP_FROM` contract `docker-entrypoint.sh` expects, the port
(8080) and user (`www-data`) it runs as, the GHCR image name, and how dadock
consumes it. Right now the SMTP contract exists only inside the entrypoint
script.

---

## Larger change, if the site is worth more investment

### [P3] Restructure the contact form
Most of the PHP findings trace back to one design: request handling,
validation, mail sending and HTML rendering interleaved in a single 599-line
template. Separating the POST handler from the template would make the
escaping, guarding and error-handling fixes straightforward rather than
fiddly, and would let a real linter run against the logic — which would also
let the `phpcs` gate come back honestly. Worth doing only if the site keeps
evolving; for a resume that rarely changes, the targeted fixes above are
enough.
