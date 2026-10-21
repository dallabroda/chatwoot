# Connects a WhatsApp number via the unofficial QR-code/Evolution API path (see
# app/services/whatsapp/evolution_connection_service.rb). The risky, unofficial
# nature of this connection method must be explicitly accepted by the admin
# before any instance is created — enforced here, not just in the UI.
class Api::V1::Accounts::WhatsappEvolutionConnectionsController < Api::V1::Accounts::BaseController
  before_action :fetch_inbox, only: [:qr, :destroy]
  rescue_from Whatsapp::EvolutionApiError, with: :render_evolution_error

  def create
    authorize Inbox.new(account: Current.account), :create?
    return render_invalid_param(:risk_accepted) unless ActiveModel::Type::Boolean.new.cast(params[:risk_accepted])
    return render_invalid_param(:name) if params[:name].blank?

    instance_name = "cw_#{Current.account.id}_#{SecureRandom.hex(6)}"
    inbox = nil
    qr_response = nil
    service = nil

    begin
      ActiveRecord::Base.transaction do
        channel = Channel::Api.create!(account: Current.account)
        inbox = Current.account.inboxes.create!(name: params[:name], channel: channel)
        channel.update!(additional_attributes: {
                           'connection_type' => 'evolution_qr',
                           'evolution_instance_name' => instance_name,
                           'connection_state' => 'qr_pending',
                           'risk_accepted_at' => Time.current,
                           'risk_accepted_by' => Current.user.email
                         })
        channel.reload

        service = Whatsapp::EvolutionConnectionService.new(channel, instance_name, inbox_name: inbox.name)
        qr_response = service.create_instance
        service.link_chatwoot(access_token: access_token_for_current_user, chatwoot_url: ENV.fetch('FRONTEND_URL', nil))
        service.register_status_webhook(evolution_status_webhook_url(instance_name))
      end
    rescue StandardError => e
      service&.delete_instance rescue nil
      raise e
    end

    render json: {
      id: inbox.id,
      instance_name: instance_name,
      qr_code: qr_response.dig('qrcode', 'base64')
    }
  end

  def qr
    service = Whatsapp::EvolutionConnectionService.new(@inbox.channel, evolution_instance_name)
    response = service.connect
    render json: { qr_code: response['base64'] || response.dig('qrcode', 'base64') }
  end

  def destroy
    service = Whatsapp::EvolutionConnectionService.new(@inbox.channel, evolution_instance_name)
    service.delete_instance
    ::DeleteObjectJob.perform_later(@inbox, Current.user, request.ip)
    head :ok
  end

  private

  def fetch_inbox
    @inbox = Current.account.inboxes.find(params[:inbox_id] || params[:id])
    authorize @inbox, :update?
    return if @inbox.channel.is_a?(Channel::Api) && evolution_instance_name.present?

    render json: { error: 'Not an Evolution-connected inbox' }, status: :unprocessable_entity
  end

  def evolution_instance_name
    @inbox.channel.additional_attributes['evolution_instance_name']
  end

  def access_token_for_current_user
    Current.user.access_token&.token || Current.user.create_access_token.token
  end

  def evolution_status_webhook_url(instance_name)
    base = ENV.fetch('RAILS_INTERNAL_URL', 'http://rails:3000')
    "#{base}/webhooks/evolution/#{instance_name}"
  end

  def render_invalid_param(name)
    render json: { error: "Invalid #{name}" }, status: :unprocessable_entity
  end

  def render_evolution_error(error)
    render json: { error: error.message }, status: :unprocessable_entity
  end
end
