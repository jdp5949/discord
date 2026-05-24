// TypeScript / Node.js >= 18 — built-in fetch.
//
// Compile + run:
//   npx tsx send.ts
// or:
//   tsc send.ts && node send.js

interface DiscordEmbed {
  title?: string;
  description?: string;
  color?: number;
  fields?: { name: string; value: string; inline?: boolean }[];
  footer?: { text: string };
  timestamp?: string;
}

interface DiscordPayload {
  username?: string;
  content?: string;
  allowed_mentions?: { parse: string[] };
  embeds?: DiscordEmbed[];
}

async function sendEmbed(
  webhookUrl: string,
  payload: DiscordPayload,
  maxRetries = 5,
): Promise<boolean> {
  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    const res = await fetch(webhookUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
    });
    if (res.ok) return true;
    if (res.status === 429) {
      const body = (await res.json()) as { retry_after?: number };
      const waitMs = Math.ceil(((body.retry_after ?? 1) + 0.05) * 1000);
      await new Promise((r) => setTimeout(r, waitMs));
      continue;
    }
    if (res.status >= 500 && attempt < maxRetries) {
      await new Promise((r) => setTimeout(r, 1000));
      continue;
    }
    console.error(`HTTP ${res.status}`, await res.text());
    return false;
  }
  return false;
}

const webhook = process.env.DISCORD_WEBHOOK;
if (!webhook) throw new Error('Set DISCORD_WEBHOOK env var');

await sendEmbed(webhook, {
  username: 'monitor-bot',
  embeds: [
    {
      title: 'Service degraded',
      description: 'API p99 over 500ms for 5 minutes',
      color: 0xff8800,
      fields: [
        { name: 'Service', value: 'checkout-api', inline: true },
        { name: 'Region', value: 'ap-south-1', inline: true },
      ],
      footer: { text: 'prometheus-alertmanager' },
      timestamp: new Date().toISOString(),
    },
  ],
});
