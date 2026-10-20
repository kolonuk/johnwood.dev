interface Env {
	EMAIL: SendEmail;
	TURNSTILE_SECRET: string;
}

interface ContactPayload {
	from_email?: string;
	message?: string;
}

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const MAX_MESSAGE_LENGTH = 5000;

function escapeHtml(value: string): string {
	return value.replace(/[&<>"']/g, (c) =>
		({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]!,
	);
}

function jsonResponse(body: unknown, status: number): Response {
	return new Response(JSON.stringify(body), {
		status,
		headers: { "Content-Type": "application/json" },
	});
}

export default {
	async fetch(request: Request, env: Env): Promise<Response> {
		if (request.method !== "POST") {
			return jsonResponse({ error: "method not allowed" }, 405);
		}

		let payload: ContactPayload;
		try {
			payload = await request.json();
		} catch {
			return jsonResponse({ error: "invalid JSON body" }, 400);
		}

		const fromEmail = (payload.from_email ?? "").trim();
		const message = (payload.message ?? "").trim();

		if (!EMAIL_RE.test(fromEmail)) {
			return jsonResponse({ error: "invalid email address" }, 400);
		}
		if (!message || message.length > MAX_MESSAGE_LENGTH) {
			return jsonResponse({ error: "message required (max 5000 chars)" }, 400);
		}

		try {
			await env.EMAIL.send({
				from: "john@kolon.co.uk",
				to: "john@kolon.co.uk",
				replyTo: fromEmail,
				subject: "johnwood.dev contact form",
				text: `From: ${fromEmail}\n\n${message}`,
				html: `<p><strong>From:</strong> ${escapeHtml(fromEmail)}</p><p>${escapeHtml(message).replace(/\n/g, "<br>")}</p>`,
			});
		} catch (err) {
			console.error("email send failed", err);
			return jsonResponse({ error: "failed to send - try again later" }, 502);
		}

		return jsonResponse({ ok: true }, 200);
	},
} satisfies ExportedHandler<Env>;
