---
title: How it works
---

# How Discord webhooks work

A webhook is a **public URL bound to one channel**. There is no bot,
no OAuth, no user account, no SDK. The full protocol is "POST JSON to
the URL." If you can `curl`, you can use it.

## The URL

```
https://discord.com/api/webhooks/<webhook_id>/<webhook_token>
```

- `<webhook_id>` — a 17-20 digit Discord snowflake (channel-bound).
- `<webhook_token>` — a 60+ char base64-url string (acts as the API key).

The token alone is what authenticates the request. Anyone who has it can
post messages to the channel (but **not** read messages, modify the
channel, or do anything else). Rotate the token if it leaks: Discord
channel settings → Integrations → Webhooks → delete + recreate.

## The request

```
POST https://discord.com/api/webhooks/<id>/<token>
Content-Type: application/json

{
  "username":   "my-bot",
  "avatar_url": "https://...",
  "content":    "optional plain text",
  "embeds": [
    {
      "title":       "An event happened",
      "description": "Markdown supported",
      "color":       16711680,
      "fields": [
        { "name": "Field A", "value": "value A", "inline": true },
        { "name": "Field B", "value": "value B", "inline": true }
      ],
      "footer":    { "text": "footer line" },
      "timestamp": "2026-05-24T12:00:00.000Z"
    }
  ],
  "allowed_mentions": { "parse": ["users", "roles"] }
}
```

Discord returns `204 No Content` on success.

## The pieces

| Field | What it controls |
|-------|------------------|
| `username` | Display name shown next to the message ("bot" name). Overrides default. |
| `avatar_url` | Override avatar per-message. |
| `content` | Plain text shown above the embed. Required if no `embeds`. |
| `embeds` | Up to 10 rich cards per message. Title + description + colour + fields + footer + timestamp. |
| `embeds[].color` | 24-bit RGB int. Common ones: `0xff0000` red, `0xff8800` orange, `0xffcc00` yellow, `0x00cc66` green, `0x3399ff` blue, `0x808080` gray. |
| `embeds[].fields[].inline` | If `true`, fields render side-by-side; `false` = full-width. |
| `allowed_mentions` | Whitelist of who actually gets pinged. Defaults to ALL mentions in `content` — set this to suppress. |

## Length limits (Discord enforces)

| Item | Max |
|------|-----|
| `content` | 2000 chars |
| `embed.title` | 256 chars |
| `embed.description` | 4096 chars |
| `embed.fields[].name` | 256 chars |
| `embed.fields[].value` | 1024 chars |
| Number of fields per embed | 25 |
| Number of embeds per message | 10 |
| Footer text | 2048 chars |
| Total embed JSON | 6000 chars |
| File attachment | 25 MB free, 500 MB Nitro |
| Username override | 80 chars |

Exceed any of these → Discord returns `400 Bad Request`.

## Rate limits

Observed empirically (Discord doesn't document precisely):

| Scope | Limit | Reset |
|-------|-------|-------|
| Per webhook | 5 requests | 1 second |
| Per webhook (soft) | ~30 messages | 60 seconds |
| Per channel (all sources) | 50 messages | 1 second |

Response includes headers:

```
x-ratelimit-limit:        5
x-ratelimit-remaining:    4
x-ratelimit-reset-after:  1
x-ratelimit-bucket:       <bucket-id>
```

When you exceed → Discord returns `429 Too Many Requests` with:

```json
{ "message": "You are being rate limited.", "retry_after": 0.5 }
```

`retry_after` is **seconds, as a float**. Sleep that long + a tiny
buffer, then retry. The Python package and every example in this repo
implement this loop.

## Failure modes worth knowing

| HTTP | Meaning | Action |
|------|---------|--------|
| `200`/`204` | Sent | Done |
| `400` | Malformed payload (too long, bad JSON, bad embed shape) | Fix the payload — don't retry |
| `401` / `403` | Webhook token invalid (deleted? wrong URL?) | Stop, fetch a fresh URL |
| `404` | Webhook deleted from the channel | Recreate or remove from config |
| `429` | Rate-limited | Sleep `retry_after`, retry |
| `5xx` | Discord transient | Sleep 1s, retry once |
| Network error | DNS/TLS/timeout | Retry with backoff |

## Phone push

Discord push is silent by default — every channel inherits the server
notification setting (default "Only @mentions"). To wake your phone for
all messages in a channel:

1. Mobile app → tap channel name → **Notifications** → **All Messages**.
2. If channel is muted at server level, also override that.
3. To bypass "Push Notification Inactive Timeout" (which suppresses
   phone push while desktop Discord is active), set timeout to 1 min in
   mobile Settings → Notifications.

To force a phone push even when channel is on "Only @mentions", include
a mention in your `content`:

```json
{
  "content": "<@&123456789012345678>",
  "allowed_mentions": { "parse": ["roles"] },
  "embeds": [ ... ]
}
```

For **wake-from-silent-mode** (iOS silent switch on, phone in DND), no
Discord push will sound — that's a hardware-level lockout. Layer one of:

- Real phone call (Twilio, CallMeBot WhatsApp call)
- Pushover Pro ($4.99/yr — iOS Critical Alerts entitlement)
- ntfy.sh priority 5 (vibrate banner, no sound on iOS silent)

Next: [language examples](languages.html).
