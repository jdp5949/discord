# Ruby — stdlib net/http. No gems required.
#
# Usage:
#   DISCORD_WEBHOOK=https://discord.com/api/webhooks/.../...  ruby send.rb

require 'net/http'
require 'json'
require 'uri'

def send_embed(webhook, payload, max_retries: 5)
  uri = URI(webhook)
  body = JSON.generate(payload)

  (1..max_retries).each do |attempt|
    Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
      req = Net::HTTP::Post.new(uri.request_uri, 'Content-Type' => 'application/json')
      req.body = body
      res = http.request(req)
      return true if res.code.to_i.between?(200, 299)
      if res.code == '429'
        info = (JSON.parse(res.body) rescue {})
        sleep((info['retry_after'] || 1.0).to_f + 0.05)
        next
      end
      if res.code.to_i >= 500 && attempt < max_retries
        sleep 1
        next
      end
      warn "HTTP #{res.code}: #{res.body}"
      return false
    end
  end
  false
end

webhook = ENV.fetch('DISCORD_WEBHOOK') { abort 'Set DISCORD_WEBHOOK env var' }

payload = {
  username: 'ruby-bot',
  embeds: [{
    title: 'New issue opened',
    description: '`#1234` Build is flaky on Windows',
    color: 0xffcc00,
    fields: [
      { name: 'Author',     value: '@octocat',     inline: true },
      { name: 'Repository', value: 'org/project',  inline: true },
      { name: 'Labels',     value: 'bug, ci',      inline: true }
    ],
    footer: { text: 'github-webhook-relay' },
    timestamp: Time.now.utc.iso8601
  }]
}

puts 'sent' if send_embed(webhook, payload)
