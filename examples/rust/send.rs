// Rust — uses `reqwest` (async) + `tokio` + `serde_json`.
//
// Cargo.toml:
//   [dependencies]
//   reqwest = { version = "0.12", features = ["json"] }
//   tokio = { version = "1", features = ["full"] }
//   serde_json = "1"
//
// Usage:
//   DISCORD_WEBHOOK=https://discord.com/api/webhooks/.../...  cargo run

use serde_json::json;
use std::env;
use std::time::Duration;
use tokio::time::sleep;

async fn send_embed(
    client: &reqwest::Client,
    webhook: &str,
    payload: &serde_json::Value,
    max_retries: u32,
) -> Result<(), Box<dyn std::error::Error>> {
    for attempt in 1..=max_retries {
        let res = client.post(webhook).json(payload).send().await?;
        let status = res.status();
        if status.is_success() {
            return Ok(());
        }
        if status.as_u16() == 429 {
            let body: serde_json::Value = res.json().await.unwrap_or(json!({}));
            let wait = body
                .get("retry_after")
                .and_then(|v| v.as_f64())
                .unwrap_or(1.0);
            sleep(Duration::from_millis(((wait + 0.05) * 1000.0) as u64)).await;
            continue;
        }
        if status.is_server_error() && attempt < max_retries {
            sleep(Duration::from_secs(1)).await;
            continue;
        }
        let text = res.text().await.unwrap_or_default();
        return Err(format!("HTTP {}: {}", status, text).into());
    }
    Err("retries exhausted".into())
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let webhook = env::var("DISCORD_WEBHOOK").expect("Set DISCORD_WEBHOOK");
    let client = reqwest::Client::builder()
        .timeout(Duration::from_secs(10))
        .build()?;

    let payload = json!({
        "username": "rust-bot",
        "embeds": [{
            "title": "Sensor reading critical",
            "description": "Tank #4 temperature 92°C (limit 85°C)",
            "color": 0xff0000,
            "fields": [
                {"name": "Sensor", "value": "tank-4-temp", "inline": true},
                {"name": "Threshold", "value": "85°C", "inline": true}
            ],
            "footer": {"text": "iot-monitor"},
            "timestamp": chrono_lite()
        }]
    });

    send_embed(&client, &webhook, &payload, 5).await?;
    println!("sent");
    Ok(())
}

fn chrono_lite() -> String {
    let secs = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap()
        .as_secs();
    // Crude ISO-8601 stringification (use `chrono` crate for production).
    format!("@{}", secs)
}
