// Java 11+ — stdlib java.net.http (no Maven deps required).
//
// Compile + run:
//   DISCORD_WEBHOOK=https://discord.com/api/webhooks/.../...  java Send.java
// (`java <single-file>.java` runs without explicit compile on Java 11+.)

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.time.Instant;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

public class Send {
    static final HttpClient CLIENT = HttpClient.newBuilder()
            .connectTimeout(Duration.ofSeconds(10))
            .build();

    static boolean sendEmbed(String webhook, String jsonPayload, int maxRetries) throws Exception {
        for (int attempt = 1; attempt <= maxRetries; attempt++) {
            HttpRequest req = HttpRequest.newBuilder(URI.create(webhook))
                    .header("Content-Type", "application/json")
                    .POST(HttpRequest.BodyPublishers.ofString(jsonPayload))
                    .timeout(Duration.ofSeconds(10))
                    .build();
            HttpResponse<String> res = CLIENT.send(req, HttpResponse.BodyHandlers.ofString());
            int code = res.statusCode();
            if (code >= 200 && code < 300) return true;
            if (code == 429) {
                double wait = parseRetryAfter(res.body());
                Thread.sleep((long) ((wait + 0.05) * 1000));
                continue;
            }
            if (code >= 500 && attempt < maxRetries) {
                Thread.sleep(1000);
                continue;
            }
            System.err.println("HTTP " + code + ": " + res.body());
            return false;
        }
        return false;
    }

    static double parseRetryAfter(String body) {
        Matcher m = Pattern.compile("\"retry_after\"\\s*:\\s*([0-9.]+)").matcher(body);
        return m.find() ? Double.parseDouble(m.group(1)) : 1.0;
    }

    public static void main(String[] args) throws Exception {
        String webhook = System.getenv("DISCORD_WEBHOOK");
        if (webhook == null) {
            System.err.println("Set DISCORD_WEBHOOK env var");
            System.exit(1);
        }

        String payload = """
            {
              "username": "java-bot",
              "embeds": [{
                "title": "JVM OOM warning",
                "description": "Heap usage 89%% (8.9 GB / 10 GB)",
                "color": 16746496,
                "fields": [
                  {"name": "Service", "value": "order-service", "inline": true},
                  {"name": "Pod",     "value": "order-7d9-xnz",  "inline": true}
                ],
                "footer": {"text": "jvm-metrics-exporter"},
                "timestamp": "%s"
              }]
            }
            """.formatted(Instant.now().toString());

        sendEmbed(webhook, payload, 5);
        System.out.println("sent");
    }
}
