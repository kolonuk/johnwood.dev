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
			// Destination is fixed and verified (Email Routing) — the binding
			// can't be used to relay to any other address. Sends as
			// john@kolon.co.uk (kolon.co.uk is already onboarded to Cloudflare,
			// not johnwood.dev) — same address Email Routing already forwards
			// to the Gmail inbox, so that forwarding rule is untouched.
			EMAIL: bindings.sendEmail({
				destinationAddress: "john@kolon.co.uk",
				allowedSenderAddresses: ["john@kolon.co.uk"],
			}),
			TURNSTILE_SECRET: bindings.secret(),
		},
	},
});
