// C# / .NET 6+
//
// Run as single-file:
//   DISCORD_WEBHOOK=https://discord.com/api/webhooks/.../...  dotnet run --project Send.csproj
// or as a script with `dotnet-script`.

using System.Net.Http.Json;
using System.Text.Json;

string? webhook = Environment.GetEnvironmentVariable("DISCORD_WEBHOOK");
if (string.IsNullOrEmpty(webhook))
{
    Console.Error.WriteLine("Set DISCORD_WEBHOOK env var");
    return 1;
}

var http = new HttpClient { Timeout = TimeSpan.FromSeconds(10) };

async Task<bool> SendEmbed(object payload, int maxRetries = 5)
{
    for (int attempt = 1; attempt <= maxRetries; attempt++)
    {
        var res = await http.PostAsJsonAsync(webhook, payload);
        if (res.IsSuccessStatusCode) return true;

        if ((int)res.StatusCode == 429)
        {
            var body = await res.Content.ReadAsStringAsync();
            double wait = 1.0;
            try { wait = JsonDocument.Parse(body).RootElement.GetProperty("retry_after").GetDouble(); }
            catch { }
            await Task.Delay(TimeSpan.FromMilliseconds((wait + 0.05) * 1000));
            continue;
        }
        if ((int)res.StatusCode >= 500 && attempt < maxRetries)
        {
            await Task.Delay(TimeSpan.FromSeconds(1));
            continue;
        }
        Console.Error.WriteLine($"HTTP {(int)res.StatusCode}: {await res.Content.ReadAsStringAsync()}");
        return false;
    }
    return false;
}

var payload = new
{
    username = "dotnet-bot",
    embeds = new[]
    {
        new
        {
            title = "User signup spike",
            description = "1,247 new signups in last 5 min (avg 50)",
            color = 0x3399ff,
            fields = new[]
            {
                new { name = "Channel", value = "organic",       inline = true },
                new { name = "Country", value = "IN",            inline = true },
                new { name = "Campaign", value = "n/a",          inline = true },
            },
            footer = new { text = "analytics-stream" },
            timestamp = DateTime.UtcNow.ToString("o"),
        }
    }
};

await SendEmbed(payload);
Console.WriteLine("sent");
return 0;
