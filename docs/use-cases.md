---
title: Use cases
---

# Use cases — 25+ real applications

Anywhere you want a low-cost, low-friction notification channel.
"Webhook → JSON → phone push" beats "build your own dashboard or pay
PagerDuty" for the vast majority of small-to-mid systems.

## Infrastructure / DevOps

1. **CI/CD notifications** — GitHub Actions / GitLab CI / Jenkins post
   build pass/fail with commit + branch + author. PRs auto-pinged.
2. **Deploy notifications** — `deploy.sh` posts version + duration +
   diff link to `#dev`.
3. **Cron job monitoring** — wrap every cron in a shell helper that
   posts success/failure with exit code + last 50 log lines.
4. **Server uptime monitoring** — Prometheus/Alertmanager → Discord
   webhook (Alertmanager has native Discord support). Same for
   Grafana, Loki, Sentry, Datadog, Bugsnag.
5. **SSL cert expiry warnings** — daily cron checks `openssl s_client`
   on every domain, posts when <30 days remain.
6. **Disk-full / OOM warnings** — node_exporter alerts → Discord.
7. **Container registry pushes** — post when a new image lands so the
   team sees it.
8. **Backup completion** — `pg_dump` / `restic backup` posts size +
   duration + checksum.
9. **Log error rate spikes** — Loki/Splunk alert when error log lines
   per minute exceed baseline.
10. **Kubernetes events** — `kubectl get events` watcher posts pod
    crashes, OOMKills, image pull errors.

## Application monitoring

11. **API latency alerts** — p99 > threshold for N minutes.
12. **Database slow-query alerts** — pg_stat_statements daily top-10
    posted to `#dev`.
13. **Background-job failures** — Celery/Sidekiq/Resque dead-letter
    queue items posted as they land.
14. **Cache hit-rate drop** — Redis hit/miss ratio dipping below
    baseline = post.
15. **Security alerts** — failed-login bursts, IP geolocation anomalies,
    new admin role assignments.

## Business / product events

16. **New signup / churn** — every new user (or only first-of-day, or
    only if revenue > $X) posted to `#growth`.
17. **Payment events** — Stripe webhook relay: every charge over $1k or
    every refund or every chargeback dispute.
18. **High-value customer activity** — VIP user logged in / hit a
    paywall / downgraded.
19. **Trading / fintech alerts** — order filled, position closed, daily
    P&L summary, risk limit breached (this repo was originally
    extracted from an algo trading system).
20. **E-commerce stock alerts** — low-inventory pings for SKUs under
    reorder threshold.
21. **SaaS feature flag changes** — every flag toggle posted so the
    team sees who flipped what.

## Personal / hobby

22. **IoT sensor alerts** — temperature, humidity, water leak,
    door/window contact. ESPHome + Home Assistant → webhook.
23. **Weather alerts** — daily forecast at 7am, or only when severe
    weather alerts fire for your area.
24. **Stock / crypto price triggers** — when a watchlist symbol hits a
    target.
25. **Sports scores** — favorite team final score, or only goals/runs.
26. **RSS / podcast new episodes** — daemon polls feeds, posts new
    items.
27. **GitHub mentions** — daemon polls `notifications.github.com`, posts
    issues/PRs mentioning you.
28. **Reminder bot** — `at`-style scheduled posts ("send msg to
    `#personal` at 5pm tomorrow").

## Security / audit

29. **Login from new IP** — webhook from auth middleware on every new
    geolocation.
30. **`sudo` log relay** — `/var/log/auth.log` tail to `#audit`.
31. **Webhook honeypot** — fake admin endpoint that posts every attempt
    so you see who's probing.
32. **CSP violation reports** — browser CSP report endpoint relays to
    `#security`.

## ChatOps

33. **Manual deploy approval** — slash-command bot (or webhook +
    button) lets a human approve a deploy from their phone.
34. **Slack-style status broadcasts** — anyone on the team can post a
    "I'm taking the system down for 5 min" notice.

## Anti-uses (where Discord webhooks are NOT enough)

- **Critical wake-from-silent-mode alerts** — iOS hardware silent mode
  blocks Discord push. Layer a real phone call (Twilio, CallMeBot WA
  call) or Pushover Pro for iOS Critical Alerts.
- **High-volume metrics streaming** — Discord is rate-limited at
  ~5/sec/webhook. Use Prometheus + Grafana for graphs, Discord only
  for state-change alerts.
- **Long-term log archive** — Discord history is unlimited but not
  designed for grep-style search at 10M+ messages. Pair with
  Loki/Elasticsearch.
- **Two-way support chat with end users** — Discord channels are for
  your team. Use Intercom/Crisp/Zendesk for customer chat.
- **Compliance-regulated audit trail** — Discord retention is up to
  Discord. For regulated industries, mirror to your own DB too.

## Combine with other tools

| Layer | Purpose | Examples |
|-------|---------|----------|
| **Discord** (this repo) | Visual, threaded, searchable | Embed colours, channels, audit mirror |
| **ntfy.sh** | Free push with priority levels | P0 wake-up vibrate + banner |
| **Pushover Pro** | iOS Critical Alerts | Silent-mode override, ~$5/yr |
| **CallMeBot / Twilio** | Real phone call | Sleep-through-anything wake-up |
| **WhatsApp** (WeSender, Twilio WA, etc.) | Family-visible alerts | Wife/spouse also sees the alert |
| **Email** | Audit trail, regulatory | Long-term archive |

A typical production stack: Discord for visual, ntfy or Pushover for
phone wake, real phone call for P0 only. Total cost: $0–$10/year.

Next: [production patterns](production-patterns.html).
