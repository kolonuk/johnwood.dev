import { bindings, defineConfig, triggers } from "cf/config";
import * as entrypoint from "./src/index.ts" with { type: "cf-worker" };

export default defineConfig({
	worker: {
		name: "johnwood-contact",
		compatibilityDate: "2026-10-06",
		// worker-mailer needs Node compat for its SMTP client.
		compatibilityFlags: ["nodejs_compat"],
		entrypoint,
		triggers: [
			triggers.fetch({
				pattern: "johnwood.dev/api/contact",
				zone: "johnwood.dev",
			}),
		],
		env: {
			// Cloudflare's own send_email binding needs Workers Paid (this
			// account is on Free), so the Worker speaks SMTP directly to
			// Gmail over a TCP socket instead — same relay the old PHP site
			// used via msmtp, same app password, just called from here.
			GMAIL_USERNAME: bindings.secret(),
			GMAIL_APP_PASSWORD: bindings.secret(),
			TURNSTILE_SECRET: bindings.secret(),
		},
	},
});
