# Handles QR/connection-status events from an Evolution API instance (see
# app/services/whatsapp/evolution_connection_service.rb#register_status_webhook).
# Message content is NOT handled here — Evolution's own native Chatwoot
# integration bridges that directly (app/listeners/webhook_listener.rb).
class Webhooks::EvolutionEventsJob < ApplicationJob
  queue_as :low

  def perform(instance_name:, params:)
    channel = Channel::Api.find_by("additional_attributes->>'evolution_instance_name' = ?", instance_name)
    return if channel.blank?

    event = params['event'].to_s.upcase.tr('.', '_')

    case event
    when 'QRCODE_UPDATED'
      handle_qr_updated(channel, params)
    when 'CONNECTION_UPDATE'
      handle_connection_update(channel, params)
    end
  end

  private

  def handle_qr_updated(channel, params)
    qr_base64 = params.dig('data', 'qrcode', 'base64') || params.dig('data', 'base64')
    update_state(channel, 'qr_pending')
    broadcast(channel, 'qr_code' => qr_base64, 'connection_state' => 'qr_pending')
  end

  def handle_connection_update(channel, params)
    connection_state = channel.apply_evolution_connection_state!(params.dig('data', 'state'))
    broadcast(channel, 'connection_state' => connection_state) if connection_state
  end

  def update_state(channel, connection_state)
    channel.update!(additional_attributes: channel.additional_attributes.merge('connection_state' => connection_state))
  end

  def broadcast(channel, data)
    ActionCable.server.broadcast(
      "account_#{channel.account_id}",
      { event: 'whatsapp_qr.updated', data: data.merge('inbox_id' => channel.inbox.id) }
    )
  end
end
