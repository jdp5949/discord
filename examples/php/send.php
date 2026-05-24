<?php
// PHP — stdlib curl. Tested on PHP 8.x.
//
// Usage:
//   DISCORD_WEBHOOK=https://discord.com/api/webhooks/.../...  php send.php

declare(strict_types=1);

$webhook = getenv('DISCORD_WEBHOOK');
if (!$webhook) {
    fwrite(STDERR, "Set DISCORD_WEBHOOK env var\n");
    exit(1);
}

function send_embed(string $webhook, array $payload, int $maxRetries = 5): bool
{
    for ($attempt = 1; $attempt <= $maxRetries; $attempt++) {
        $ch = curl_init($webhook);
        curl_setopt_array($ch, [
            CURLOPT_POST           => true,
            CURLOPT_POSTFIELDS     => json_encode($payload),
            CURLOPT_HTTPHEADER     => ['Content-Type: application/json'],
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_TIMEOUT        => 10,
        ]);
        $body = curl_exec($ch);
        $code = curl_getinfo($ch, CURLINFO_RESPONSE_CODE);
        curl_close($ch);

        if ($code >= 200 && $code < 300) {
            return true;
        }
        if ($code === 429) {
            $data = json_decode((string)$body, true) ?: [];
            $wait = (float)($data['retry_after'] ?? 1.0);
            usleep((int)(($wait + 0.05) * 1_000_000));
            continue;
        }
        if ($code >= 500 && $attempt < $maxRetries) {
            sleep(1);
            continue;
        }
        fwrite(STDERR, "HTTP $code: $body\n");
        return false;
    }
    return false;
}

$payload = [
    'username' => 'php-bot',
    'embeds'   => [[
        'title'       => 'Payment received',
        'description' => 'New subscriber tier=`pro`',
        'color'       => 0x00cc66,
        'fields'      => [
            ['name' => 'Amount',  'value' => '$49.00',  'inline' => true],
            ['name' => 'Plan',    'value' => 'pro',     'inline' => true],
            ['name' => 'Country', 'value' => 'IN',      'inline' => true],
        ],
        'footer'      => ['text' => 'stripe-webhook'],
        'timestamp'   => gmdate('c'),
    ]],
];

if (send_embed($webhook, $payload)) {
    echo "sent\n";
}
