# TODO

## High priority
- [ ] Add social metadata to the document head (`og:title`, `og:description`, `og:image`, `twitter:card`) in `src/layouts/Layout.astro`.

## Medium priority
- [ ] Decide whether the GHCR package should stay private or document the required `GH_PAT` login as a deploy prerequisite.
- [ ] CI smoke test POSTs through the honeypot and type-human checks, but not the Turnstile, rate-limit or mail branches.
- [ ] Make `src/data/resume.json` the single source of truth for the contact email everywhere it is referenced — `php/contact.php` still hardcodes `john@kolon.co.uk` separately from `basics.email`.

## Optional
- [ ] Add image provenance/signing if supply-chain security becomes a priority.

## Done
- [x] Contact form path-prefix bug (`action="/contact.php"`, `href="/#contact"`) — fixed, both now relative.
