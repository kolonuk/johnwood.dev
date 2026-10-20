<?php
declare(strict_types=1);

function render(string $title, string $body): never
{
    http_response_code($title === 'Message sent' ? 200 : 400);
    echo <<<HTML
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>{$title} — John Wood</title>
<style>body{max-width:40rem;margin:4rem auto;padding:0 1.5rem;font-family:system-ui,sans-serif;text-align:center;color:#1c2228}a{color:#3b82f6}</style>
</head>
<body>
<h1>{$title}</h1>
<p>{$body}</p>
<p><a href="/#contact">Back to johnwood.dev</a></p>
</body>
</html>
HTML;
    exit;
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    exit;
}

// Honeypot: a field no real visitor sees or fills in (hidden via CSS, not
// `type=hidden`, since bots skip genuinely hidden inputs less reliably).
// Non-empty means a bot filled every field it found — accept silently
// without sending mail, so the bot gets no signal its submission failed.
if (($_POST['company'] ?? '') !== '') {
    render('Message sent', 'Thanks for getting in touch.');
}

// Visible challenge, same idea as the original site's "type human" field.
if (strtolower(trim((string) ($_POST['uniquecapture'] ?? ''))) !== 'human') {
    render('Capture failed', 'Type "human" in the capture field and try again.');
}

$turnstileSecret = getenv('TURNSTILE_SECRET');
if ($turnstileSecret !== false && $turnstileSecret !== '') {
    $token = (string) ($_POST['cf-turnstile-response'] ?? '');
    if ($token === '') {
        render('Capture failed', 'Complete the Turnstile check and try again.');
    }
    $ch = curl_init('https://challenges.cloudflare.com/turnstile/v0/siteverify');
    curl_setopt_array($ch, [
        CURLOPT_POST => true,
        CURLOPT_POSTFIELDS => http_build_query([
            'secret' => $turnstileSecret,
            'response' => $token,
            'remoteip' => $_SERVER['REMOTE_ADDR'] ?? '',
        ]),
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_TIMEOUT => 5,
    ]);
    $result = curl_exec($ch);
    curl_close($ch);
    $verified = is_string($result) ? json_decode($result, true) : null;
    if (!is_array($verified) || ($verified['success'] ?? false) !== true) {
        render('Capture failed', 'The Turnstile check did not pass — try again.');
    }
}

$fromEmail = trim((string) ($_POST['from_email'] ?? ''));
$message = trim((string) ($_POST['message'] ?? ''));

if (!filter_var($fromEmail, FILTER_VALIDATE_EMAIL) || str_contains($fromEmail, "\r") || str_contains($fromEmail, "\n")) {
    render('Invalid email', 'That email address doesn\'t look right — go back and try again.');
}
if ($message === '' || mb_strlen($message) > 5000) {
    render('Message required', 'Enter a message (up to 5000 characters) and try again.');
}

$to = 'john@kolon.co.uk';
$subject = 'johnwood.dev contact form';
$body = "From: {$fromEmail}\n\n{$message}";
$headers = "Reply-To: {$fromEmail}\r\nContent-Type: text/plain; charset=UTF-8";

if (mail($to, $subject, $body, $headers)) {
    render('Message sent', 'Thanks for getting in touch — I\'ll reply as soon as I can.');
}

render('Something went wrong', 'The message could not be sent right now — try again later, or email john@kolon.co.uk directly.');
