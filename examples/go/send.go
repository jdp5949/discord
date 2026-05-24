// Go — stdlib net/http only.
//
// Usage:
//   DISCORD_WEBHOOK=https://discord.com/api/webhooks/.../... go run send.go

package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"time"
)

type embedField struct {
	Name   string `json:"name"`
	Value  string `json:"value"`
	Inline bool   `json:"inline,omitempty"`
}

type embedFooter struct {
	Text string `json:"text"`
}

type discordEmbed struct {
	Title       string       `json:"title,omitempty"`
	Description string       `json:"description,omitempty"`
	Color       int          `json:"color,omitempty"`
	Fields      []embedField `json:"fields,omitempty"`
	Footer      *embedFooter `json:"footer,omitempty"`
	Timestamp   string       `json:"timestamp,omitempty"`
}

type payload struct {
	Username        string         `json:"username,omitempty"`
	Content         string         `json:"content,omitempty"`
	AllowedMentions any            `json:"allowed_mentions,omitempty"`
	Embeds          []discordEmbed `json:"embeds,omitempty"`
}

func sendEmbed(webhook string, p payload, maxRetries int) error {
	body, _ := json.Marshal(p)
	client := &http.Client{Timeout: 10 * time.Second}
	for attempt := 1; attempt <= maxRetries; attempt++ {
		resp, err := client.Post(webhook, "application/json", bytes.NewReader(body))
		if err != nil {
			if attempt < maxRetries {
				time.Sleep(time.Second)
				continue
			}
			return err
		}
		defer resp.Body.Close()
		if resp.StatusCode >= 200 && resp.StatusCode < 300 {
			return nil
		}
		if resp.StatusCode == 429 {
			var ra struct {
				RetryAfter float64 `json:"retry_after"`
			}
			b, _ := io.ReadAll(resp.Body)
			_ = json.Unmarshal(b, &ra)
			if ra.RetryAfter == 0 {
				ra.RetryAfter = 1
			}
			time.Sleep(time.Duration((ra.RetryAfter+0.05)*1000) * time.Millisecond)
			continue
		}
		if resp.StatusCode >= 500 && attempt < maxRetries {
			time.Sleep(time.Second)
			continue
		}
		b, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("http %d: %s", resp.StatusCode, string(b))
	}
	return fmt.Errorf("exhausted %d retries", maxRetries)
}

func main() {
	webhook := os.Getenv("DISCORD_WEBHOOK")
	if webhook == "" {
		fmt.Fprintln(os.Stderr, "set DISCORD_WEBHOOK")
		os.Exit(1)
	}
	err := sendEmbed(webhook, payload{
		Username: "go-bot",
		Embeds: []discordEmbed{{
			Title:       "Deploy successful",
			Description: "v2.1.0 promoted to prod-ap-south-1",
			Color:       0x00cc66,
			Fields: []embedField{
				{Name: "Commit", Value: "a1b2c3d", Inline: true},
				{Name: "Duration", Value: "47s", Inline: true},
			},
			Footer:    &embedFooter{Text: "go-deploy-script"},
			Timestamp: time.Now().UTC().Format(time.RFC3339),
		}},
	}, 5)
	if err != nil {
		fmt.Fprintln(os.Stderr, "send error:", err)
		os.Exit(1)
	}
	fmt.Println("sent")
}
