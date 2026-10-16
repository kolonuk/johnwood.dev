# TODO — johnwood.dev

Review of the containerised resume site (`src/`) and its build pipeline.
Findings are ordered by priority. Each item notes how it was verified.

Legend: **[P1]** blocking / actively exploitable · **[P2]** should fix ·
**[P3]** nice to have

---

## Blocking

### [P1] The CI lint gate fails, so no image can ever be published
`phpcs --standard=PSR12` in `.github/workflows/docker-build-push.yml` reports
**144 errors / 78 warnings** on `src/index.php`. The `lint-php` job exits
non-zero, `build` lists it in `needs:`, so the pipeline never reaches the push
step. Verified by running phpcs 4.x against `src/` in a `php:8.2-cli`
container.

PSR-12 is the wrong standard for a file that is 90% HTML with inline PHP — it
will never pass without a full rewrite. Pick one:

- Drop `phpcs` and keep only `php -l` (syntax check), which passes today.
- Keep `phpcs` but scope it to a rule subset that suits inline-HTML templates,
  and add a `phpcs.xml` to the repo so local and CI runs agree.
- Rewrite `index.php` to separate logic from template, then PSR-12 applies
  honestly (see "Restructure the contact form" below).

Recommendation: drop `phpcs` now, revisit if the PHP is ever restructured.

### [P1] PHP warnings and file paths are rendered to every visitor
The container ships no `php.ini`, so PHP falls back to `display_errors=1`.
The live page currently emits, in the HTML body:

```
Warning:  Undefined array key "from_email" in /var/www/html/index.php on line 503
Warning:  Undefined array key "message" in /var/www/html/index.php on line 504
Deprecated:  Constant FILTER_SANITIZE_STRING is deprecated in /var/www/html/index.php on line 504
Warning:  Undefined array key "uniquecapture" in /var/www/html/index.php on line 506
```

Verified with `curl` against the built image. This leaks absolute paths and
line numbers, and looks broken to users. Two fixes, do both:

1. In `src/Dockerfile`, activate the production INI that the base image already
   carries: `RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"`.
   That sets `display_errors=Off` and logs to stderr instead.
2. Fix the underlying bugs — `src/index.php:503-506` read `$_POST[...]` keys
   unconditionally, and `$recaptureMsg` (`:513`) is undefined on any GET
   request. Guard with `$_SERVER['REQUEST_METHOD'] === 'POST'` and use `??`
   defaults.

Note (1) alone only hides the problem; (2) alone still leaves a container with
developer error display enabled in production.

---

## Security

### [P2] Rotate the committed reCAPTCHA secret
`src/index.php:484` has the secret key inline, and it is in git history, so
rotating the file is not enough — issue a new key pair in the reCAPTCHA admin
console and retire the old one. Then read it from the environment
(`getenv('RECAPTCHA_SECRET')`) and pass it to the container the same way the
SMTP credentials are passed. The site key on `:520` is public by design and
does not need rotating.

### [P2] Send the reCAPTCHA secret in a POST body, not a query string
`src/index.php:485` puts the secret in the URL of a GET request. URLs are
logged by proxies and appear in error messages. Switch to a cURL POST to
`https://www.google.com/recaptcha/api/siteverify` with the parameters in the
request body.

### [P2] The reCAPTCHA verification call has no timeout
`file_get_contents()` on `:485` uses PHP's `default_socket_timeout` (60s). A
slow or unreachable Google endpoint holds an Apache worker for a full minute
per request, which makes the contact form a cheap way to exhaust the worker
pool. Use cURL with an explicit `CURLOPT_TIMEOUT` of a few seconds, and treat
a failed call as verification failure (which is what the current code does by
accident, via `json_decode(false) === null`).

### [P2] Output is never escaped
`$from_email`, `$message` and `$uniquecapture` are echoed back into the page
(`:510`, `:518-521`) relying solely on the input filters. `FILTER_SANITIZE_STRING`
is deprecated (it is one of the warnings above) and is slated for removal; when
it goes, `$message` and `$uniquecapture` become raw reflected XSS. Escape on
output with `htmlspecialchars($v, ENT_QUOTES, 'UTF-8')` regardless of what the
input filter did — filter on input, escape on output, always both.

### [P2] No rate limiting on the contact form
Now that `mail()` relays through a real Gmail account, an unthrottled form is a
route to getting that account flagged or suspended for spam. reCAPTCHA raises
the cost but does not cap volume. Add a per-IP throttle, or move sending to an
API with its own quotas and abuse handling.

### [P2] jQuery 1.12.4 is loaded from a CDN
`src/index.php:595` pulls jQuery 1.12.4 (released 2016). Versions before 3.5.0
carry known XSS issues (CVE-2020-11022, CVE-2020-11023). Upgrade to a current
3.x, and self-host it so the site does not depend on a third-party origin at
runtime.

### [P3] Subresource Integrity is missing on most third-party assets
Four external `<script>`/`<link>` tags, only one carries an `integrity`
attribute. Add SRI hashes to the rest, or self-host them. Self-hosting also
removes the third-party requests the page currently makes on every load.

### [P3] No security response headers
Apache sends no `Content-Security-Policy`, `X-Content-Type-Options`,
`Referrer-Policy` or `X-Frame-Options`. Add them via an Apache conf fragment in
the image, or at the ingress/proxy in front of the cluster — decide which layer
owns this so it is not set twice with conflicting values.

### [P3] SMTP credentials are reachable from PHP
`docker-entrypoint.sh` writes the Gmail app password to
`/var/www/msmtp/msmtprc` as `www-data`, which is also the user PHP runs as, so
any file-disclosure bug in PHP exposes it. This is inherent to the msmtp
approach and is acceptable given the credential is a scoped app password — but:

- Have the entrypoint `unset SMTP_PASSWORD` before `exec`, so the value is not
  left in the Apache process environment and visible via `/proc/*/environ` or
  `docker inspect`.
- Prefer mounting the credential as a file (Docker/Kubernetes secret) over
  passing it as an environment variable.

### [P3] Email header injection is only incidentally blocked
`src/index.php:529` concatenates user input into a `Reply-to:` mail header.
`FILTER_SANITIZE_EMAIL` happens to strip CR and LF, which is what stops header
injection today. Reject strings containing `\r` or `\n` explicitly rather than
relying on that side effect.

### [P3] No CSRF token on the contact form
reCAPTCHA partially covers this. Low impact for a form that only sends mail to
the site owner, but worth adding if the form ever does anything else.

---

## Build pipeline

### [P1] The image is pushed before it is scanned
In `.github/workflows/docker-build-push.yml`, `build` pushes both
`:${{ github.sha }}` and `:latest`, and `trivy-image-scan` runs afterwards as a
separate job. A vulnerable image is therefore public in Artifact Registry —
and `:latest` already points at it — before the gate that is supposed to block
it. Restructure to: build locally → scan → push on pass. Push `:latest` only
after every gate is green, so a cluster tracking `:latest` can never pull an
image that failed its scan.

### [P2] Add a smoke test before pushing
Nothing verifies the built image actually serves traffic. A broken Apache
config or a bad `COPY` would ship. Run the container in the workflow, curl `/`,
and require HTTP 200 before push. This is the check that caught the
`display_errors` problem above, and it costs a few seconds.

### [P2] Pin the remaining actions to commit SHAs
Most actions are SHA-pinned, but `shivammathur/setup-php@v2` and
`hadolint/hadolint-action@v3.1.0` are pinned to mutable tags. A tag can be
repointed at new code by whoever owns the repository. Pin all of them or none;
the current mix gives the appearance of supply-chain hygiene without the
guarantee.

### [P2] Narrow per-job permissions
`id-token: write` is granted at workflow level, so the lint and scan jobs get a
token they never use. Drop the top-level grant to `contents: read` and add
`id-token: write` only to the jobs that authenticate to Google Cloud.

### [P3] The Trivy filesystem scan finds nothing
`trivy-fs` scans `src/` for vulnerable dependencies, but after the cleanup
there are no dependency manifests left — no `composer.json`, no
`package.json`. The job runs for about a minute and can only ever pass. Either
drop it, or repoint it at configuration scanning (`scan-type: config`) so it
lints the Dockerfile for misconfigurations instead.

### [P3] No build caching
Every run reinstalls apt packages and recompiles the PHP extensions (~30s).
Switch to `docker/build-push-action` with GitHub Actions cache
(`cache-from: type=gha`) to skip that when the Dockerfile has not changed.

### [P3] No image signing or provenance
For a publicly pullable image, consider cosign signatures and SBOM generation
so consumers can verify what they are running.

### [P3] Enable Dependabot for GitHub Actions
Nothing currently tells you when a pinned action has a security update. Add
`.github/dependabot.yml` with the `github-actions` ecosystem.

---

## Image

### [P2] PHP 8.2 reaches end of life in December 2026
Active support ended in December 2024; security support ends 2026-12-31 — about
four months out. Move to 8.3 or 8.4. Test the contact form when you do:
`FILTER_SANITIZE_STRING` is deprecated and its removal is what makes the output
escaping item above urgent rather than theoretical.

### [P3] Pin the base image by digest
`FROM php:8.2-apache` is a moving tag, so two builds of the same commit can
produce different images. Pin `php:8.2-apache@sha256:...` and update it
deliberately.

### [P3] The image is 729 MB
`libonig-dev` and `libxml2-dev` are build-time dependencies that stay in the
final layer. Remove them after `docker-php-ext-install`, or use a multi-stage
build that copies only the compiled `.so` files. The runtime needs `libonig5`
and `libxml2`, which the base image already has.

### [P3] No HEALTHCHECK
Add a `HEALTHCHECK` so the orchestrator can tell a wedged Apache from a healthy
one. A static path is enough — there is no dynamic health endpoint and this
site does not need one.

---

## Documentation

### [P2] Write a README
`README.md` was deleted along with the App Engine setup and nothing replaced
it. It should cover: what the image is, how to build and run it, the
`SMTP_USER` / `SMTP_PASSWORD` / `SMTP_FROM` contract that
`docker-entrypoint.sh` expects, the port (8080) and user (`www-data`) it runs
as, and which GitHub secrets the workflow needs. Without this the SMTP
environment-variable contract exists only inside the entrypoint script.

### [P2] Document the one-time Google Cloud setup
The workflow header comments name the Artifact Registry commands and the IAM
roles required (`artifactregistry.writer`, `artifactregistry.repoAdmin`), but
the Workload Identity Federation setup itself is undocumented — the script that
used to create it, `scripts/deploy-githubactions.sh`, was deleted. Capture the
WIF pool/provider setup so it can be rebuilt.

### [P3] Refresh the dual-graph index
`.dual-graph/` still indexes the old `old_site/` paths and returns stale
recommendations after the rename to `src/`. Re-run a scan.

---

## Larger change, if the site is worth more investment

### [P3] Restructure the contact form
Most of the PHP findings above trace back to one design: request handling,
validation, mail sending and HTML rendering are interleaved in a single 599-line
template. Separating the POST handler from the template would make the
escaping, guarding and error-handling fixes straightforward rather than fiddly,
and would let a real linter run against the logic. Worth doing only if the site
is going to keep evolving — if it is a static resume that rarely changes, the
targeted fixes above are enough.

### [P3] Reconsider whether the site needs PHP at all
The dynamic surface is one contact form. Everything else is static. Moving the
form to a hosted form service or a small serverless function would let this
become a static image (nginx or similar), which would drop the image from
729 MB to a few megabytes and remove the entire PHP attack surface, the SMTP
credential handling, and the mail relay abuse risk in one move.
