# Keeps the most recent raw WhatsApp webhook payloads of an account for debugging
class Whatsapp::WebhookEventLog
  MAX_EVENTS = 100

  def initialize(account)
    @key = "whatsapp_webhook_events:#{account.id}"
  end

  def record(payload)
    Redis::Alfred.lpush(@key, { received_at: Time.current.iso8601, payload: payload }.to_json)
    Redis::Alfred.ltrim(@key, 0, MAX_EVENTS - 1)
  end

  def events
    Redis::Alfred.lrange(@key).map { |event| JSON.parse(event) }
  end
end
