// Node.js >= 18 — uses the built-in fetch API. No npm install required.
//
// Usage:
//   DISCORD_WEBHOOK=https://discord.com/api/webhooks/.../...  node send.js

const WEBHOOK = process.env.DISCORD_WEBHOOK;
if (!WEBHOOK) {
  console.error('Set DISCORD_WEBHOOK env var first.');
  process.exit(1);
}

async function send(payload) {
  const res = await fetch(WEBHOOK, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
  });
  if (res.status === 429) {
    const body = await res.json();
    const waitMs = Math.ceil((body.retry_after || 1) * 1000) + 50;
    console.warn(`429 — sleeping ${waitMs}ms then retrying`);
    await new Promise((r) => setTimeout(r, waitMs));
    return send(payload);
  }
  if (!res.ok) {
    console.error(`HTTP ${res.status}`, await res.text());
  }
}

const embed = {
  title: 'Build failed',
  description: '`npm test` exited with code 1 on commit `a1b2c3d`.',
  color: 0xff0000,
  fields: [
    { name: 'Branch', value: 'main', inline: true },
    { name: 'CI', value: 'github-actions', inline: true },
    { name: 'Author', value: '@jay', inline: true },
  ],
  footer: { text: 'ci-bot' },
  timestamp: new Date().toISOString(),
};

await send({
  username: 'ci-bot',
  content: '<@&123456789012345678>', // role ping
  allowed_mentions: { parse: ['roles'] },
  embeds: [embed],
});

console.log('sent');
