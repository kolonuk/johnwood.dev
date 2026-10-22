# TODO

## High priority
- [ ] Add social metadata to the document head (`og:title`, `og:description`, `og:image`, `twitter:card`) in `src/layouts/Layout.astro`.

## Medium priority
- [ ] Add `.github/dependabot.yml` for GitHub Actions and npm updates.
- [ ] Decide whether the GHCR package should stay private or document the required `GH_PAT` login as a deploy prerequisite.
- [ ] CI smoke test covers `contact.php` GET→405 and the PDF route, but not a POST through the honeypot/type-human/Turnstile/rate-limit chain. Add one (TURNSTILE_SECRET unset in CI, so it'd exercise everything except the Turnstile branch).
- [ ] Make `src/data/resume.json` the single source of truth for the contact email everywhere it is referenced — `php/contact.php` still hardcodes `john@kolon.co.uk` separately from `basics.email`.

## Optional
- [ ] Add image provenance/signing if supply-chain security becomes a priority.

## Done
- [x] Contact form path-prefix bug (`action="/contact.php"`, `href="/#contact"`) — fixed, both now relative.
