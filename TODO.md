# TODO

## High priority
- [ ] Fix the contact form for path-prefixed deployments. `src/pages/index.astro` posts to `/contact.php`, and `php/contact.php` links back to `/#contact`, which breaks when the site is served under `/johnwood/` or another prefix.
- [ ] Add social metadata to the document head (`og:title`, `og:description`, `og:image`, `twitter:card`) in `src/layouts/Layout.astro`.

## Medium priority
- [ ] Add `.github/dependabot.yml` for GitHub Actions and npm updates.
- [ ] Decide whether the GHCR package should stay private or document the required `GH_PAT` login as a deploy prerequisite.
- [ ] Add a small smoke-test/check for the contact form and PDF route so regressions are caught in CI.
- [ ] Make `src/data/resume.json` the single source of truth for the contact email everywhere it is referenced, including the front-end obfuscated email and the PHP mail recipient logic.

## Optional
- [ ] Add image provenance/signing if supply-chain security becomes a priority.
