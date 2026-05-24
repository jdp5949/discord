---
title: Production patterns
---

# Production patterns

Things you'll want when you go past "hello world."

## 1. Async fire-and-forget queue

The send is HTTPS — typically 100-300 ms from India. Don't block your
hot path. Wrap the send in a daemon thread + bounded queue:

```python
# Python — drop alongside your DiscordSender
import queue, threading

_Q = queue.Queue(maxsize=500)

def _worker():
    while True:
        task = _Q.get()
        try:
            task()
        finally:
            _Q.task_done()

threading.Thread(target=_worker, daemon=True).start()

def anotify(channel, embed, content=""):
    try:
        _Q.put_nowait(lambda: sender.send_embed(channel, embed, content=content))
    except queue.Full:
        pass  # drop overflow
```

In Node, use a simple in-memory queue plus a worker loop. In Go, a
buffered channel + goroutine. In Rust, `tokio::spawn`.

## 2. Throttle / dedup

Bug fires same error 10,000× in 30 sec? You'll burn the 5-per-sec rate
limit, fill `#alerts` with junk, and miss the next genuine alert.

Add a small in-memory throttle:

```python
import time
_BUCKET: dict[str, list[float]] = {}
_WINDOW = 60.0
_MAX = 3

def throttle_allow(key: str) -> bool:
    now = time.monotonic()
    ts = [t for t in _BUCKET.get(key, []) if now - t < _WINDOW]
    if len(ts) >= _MAX:
        return False
    ts.append(now)
    _BUCKET[key] = ts
    return True

# Key = severity + summary, NOT full error text
if throttle_allow(f"error:{ctx}:{exc.__class__.__name__}"):
    notify(P1, "Error", str(exc))
```

Rule of thumb: 3 sends per key per 60 sec catches most storms without
suppressing real recurring problems.

## 3. 429 Retry-After backoff (mandatory)

The Python package does this. Every language example in this repo
does this. **If you're rolling your own, do it too.** Without backoff
a single burst will lose messages silently:

```
HTTP 429
{ "message": "You are being rate limited.", "retry_after": 0.5 }
```

Sleep `retry_after + 0.05`, retry up to 5 times.

## 4. Audit mirror

For long-term searchability, fire every event a second time as a
compact one-liner to a dedicated `#audit` channel. Mute that channel —
you'll never look at it day-to-day, but six months later when you need
to know what fired during last quarter's incident, it's a single
scrollable feed.

The Python package does this automatically when you set
`audit_channel=Channel.AUDIT`.

## 5. Embed colour code

```
RED     0xFF0000  P0 — system down, page someone
ORANGE  0xFF8800  P1 — degraded, manual action soon
YELLOW  0xFFCC00  P2 — investigate when free
GREEN   0x00CC66  P3 — positive event (deploy, signup, fill)
BLUE    0x3399FF  P3 — neutral event (trade, fill)
GRAY    0x808080  DEV — debug noise
WHITE   0xFFFFFF  audit mirror
```

You scan colour, not text. Triage in under 1 second.

## 6. `@everyone` for P0 only

```python
sender.send_embed(
    Channel.ALERTS,
    embed,
    content="@everyone",  # forces push even on @mentions-only setting
    allowed_mentions={"parse": ["everyone"]},
)
```

If you use this for P1 too, your team learns to ignore @everyone. Save
it.

## 7. Footgun: `allowed_mentions` default

If you POST a message with `content` containing `<@123...>` or
`@everyone` and no `allowed_mentions` field, Discord pings literally
**everyone** the IDs match by default. Always set
`allowed_mentions: {"parse": []}` (or list only what you intend) when
your `content` might include mention syntax from user data.

## 8. Secret hygiene

- Webhook URLs are secrets. Treat like API tokens.
- Store in env vars or a secret manager (Vault, AWS Secrets Manager,
  doppler, 1Password CLI). **Never commit.**
- Add a pre-commit hook that greps for
  `discord\.com/api/webhooks/[0-9]{17,20}/[A-Za-z0-9_-]{50,}` in
  staged diffs and blocks. Sample one is in this repo at
  `scripts/git-hooks/pre-commit-discord-leak.sh`.
- Rotate quarterly + after any suspicious access. Rotation is
  zero-downtime: create new webhook, swap env var, delete old.
- `__repr__` / logging should never include URL. Python package masks
  it; if you port to another language, do the same.

## 9. Boot-time health check

On service startup, POST a harmless "service started" embed to a
muted channel. If it fails, you know config is broken **before** the
first real alert needs to fire.

```python
# In your service init
try:
    ok = sender.send_embed(
        Channel.DEV,
        build_embed(title="service-x started", description=str(version), color=0x808080),
    )
    if not ok:
        log.warning("Discord notifier not reachable at boot")
except Exception:
    log.exception("Discord notifier boot probe failed")
```

## 10. Test-suite guard

If your code uses the package in a class constructor (think:
`OrderManager.__init__()` building a real `DiscordSender`), test runs
**will fire real messages** unless you defend against it. Either:

- Mock the sender in every test fixture, OR
- Add a conftest that scrubs `DISCORD_WEBHOOK_*` env vars + sets a
  master `NOTIFY_DISCORD_ENABLED=0` flag for the test session

Sample conftest in this repo at `conftest.py` of the parent project
(`dhan-market-data`).

## 11. Use threads for postmortems

When a P0 fires, reply to the embed inside Discord (right-click → Reply
in Thread). The incident discussion stays attached to the alert,
forever searchable. Better than Slack's "where did we discuss that?".

## 12. Webhook != bot

Webhooks can't read messages, can't respond to commands, can't see
reactions, can't browse history. They are write-only. If you need
two-way ChatOps (slash commands, button interactions), create a real
Discord bot via the Developer Portal — much more setup, OAuth required.

Next: [reference](reference.html).
