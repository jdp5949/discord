# Changelog

## 0.1.0 — 2026-05-24

First extraction from `dhan-market-data` into a standalone, portable package.

### Added
- `DiscordSender` — stdlib-only webhook transport with 429 Retry-After
  backoff, optional audit mirror, secret-safe `__repr__`/logging.
- `Channel` / `Severity` enums + `channel_for` / `color_for` routing
  helpers.
- `build_embed` — embed dict builder with Discord length limits enforced.
- Severity colour palette constants (`COLOR_P0` ... `COLOR_DEV`).
- 30+ unit tests covering sender, channels, embed builder.
- `README.md` + `USAGE.md` documenting portable reuse.
- MIT licence.

### Notes
- No runtime dependencies (stdlib only).
- Python 3.10+ supported.
- Failure-silent: send returns `False` on error, never raises.
