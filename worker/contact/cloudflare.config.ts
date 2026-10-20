import { bindings, defineConfig, triggers } from "cf/config";
import * as entrypoint from "./src/index.ts" with { type: "cf-worker" };

export default defineConfig({
	worker: {
		name: "johnwood-contact",
		compatibilityDate: "2026-10-06",
		entrypoint,
		triggers: [
			triggers.fetch({
				pattern: "johnwood.dev/api/contact",
				zone: "johnwood.dev",
			}),
		],
		env: {
			// Cloudflare's own send_email binding needs Workers Paid; this
			// account is on Free. Resend's free tier sends the mail instead
			// — recipient is always john@kolon.co.uk regardless of who
			// filled the form, so no domain verification is required there.
			RESEND_API_KEY: bindings.secret(),
			TURNSTILE_SECRET: bindings.secret(),
		},
	},
});
