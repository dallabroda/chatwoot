# Orchestrates linking a Chatwoot Channel::Api inbox to a self-hosted Evolution API
# instance (unofficial WhatsApp-Web/QR connection) via Evolution's native Chatwoot
# integration. See app/models/channel/api.rb and app/listeners/webhook_listener.rb
# for how Chatwoot already bridges Channel::Api message content with no extra code.
class Whatsapp::EvolutionConnectionService
  def initialize(channel, instance_name, inbox_name: nil)
    @channel = channel
    @instance_name = instance_name
    @inbox_name = inbox_name
  end

  # Creates the WhatsApp-Web session on Evolution, returns the initial QR payload.
  def create_instance
    post('/instance/create', instanceName: @instance_name, qrcode: true, integration: 'WHATSAPP-BAILEYS')
  end

  # Links this Evolution instance to the already-created Channel::Api inbox, then
  # stamps the inbox's own webhook_url with the one Evolution hands back — Evolution
  # does not do this automatically (confirmed by manual testing).
  def link_chatwoot(access_token:, chatwoot_url:)
    inbox_name = @inbox_name.presence || @channel.inbox&.name || @channel.reload.inbox&.name
    response = post("/chatwoot/set/#{@instance_name}",
                    enabled: true,
                    accountId: @channel.account_id.to_s,
                    token: access_token,
                    url: chatwoot_url,
                    signMsg: true,
                    reopenConversation: true,
                    conversationPending: false,
                    nameInbox: inbox_name,
                    autoCreate: false)

    @channel.update!(webhook_url: response['webhook_url']) if response['webhook_url'].present?
    response
  end

  # Subscribes this instance's QR/connection status events to our own thin webhook
  # receiver (app/controllers/webhooks/evolution_controller.rb) — message content
  # itself is not part of this subscription, only connection lifecycle.
  def register_status_webhook(webhook_url)
    post("/webhook/set/#{@instance_name}",
         webhook: { enabled: true, url: webhook_url, events: %w[QRCODE_UPDATED CONNECTION_UPDATE] })
  end

  def connect
    get("/instance/connect/#{@instance_name}")
  end

  # Raw Evolution/Baileys state: 'open', 'connecting' or 'close'
  def connection_state
    get("/instance/connectionState/#{@instance_name}").dig('instance', 'state')
  end

  def delete_instance
    delete("/instance/delete/#{@instance_name}")
  end

  def logout_instance
    delete("/instance/logout/#{@instance_name}")
  end

  private

  def get(path)
    request(:get, path)
  end

  def post(path, body)
    request(:post, path, body)
  end

  def delete(path)
    request(:delete, path)
  end

  def request(method, path, body = nil)
    options = { headers: headers, timeout: 15 }
    options[:body] = body.to_json if body
    response = HTTParty.public_send(method, "#{base_url}#{path}", options)
    raise Whatsapp::EvolutionApiError.from_response(response) unless response.success?

    response.parsed_response
  end

  def headers
    { 'apikey' => ENV.fetch('EVOLUTION_API_KEY'), 'Content-Type' => 'application/json' }
  end

  def base_url
    ENV.fetch('EVOLUTION_API_BASE_URL', 'http://evolution-api:8080')
  end
end
