class Api::V1::Accounts::InboxWhatsappPhoneNumbersController < Api::V1::Accounts::BaseController
  CODE_METHODS = %w[SMS VOICE].freeze
  SIX_DIGITS = /\A\d{6}\z/

  before_action :fetch_inbox
  before_action :validate_cloud_channel
  rescue_from Whatsapp::MetaApiError, with: :render_meta_error

  def request_code
    return render_invalid_param(:code_method) unless CODE_METHODS.include?(params[:code_method])

    phone_number_service.request_code(params[:code_method], params.fetch(:language, 'pt_BR'))
    head :ok
  end

  def verify_code
    return render_invalid_param(:code) unless params[:code].to_s.match?(SIX_DIGITS)

    phone_number_service.verify_code(params[:code])
    head :ok
  end

  def register
    return render_invalid_param(:pin) unless params[:pin].to_s.match?(SIX_DIGITS)

    phone_number_service.register(params[:pin])
    head :ok
  end

  def deregister
    phone_number_service.deregister
    head :ok
  end

  private

  def fetch_inbox
    @inbox = Current.account.inboxes.find(params[:inbox_id])
    authorize @inbox, :update?
  end

  def validate_cloud_channel
    return if @inbox.whatsapp? && @inbox.channel.provider == 'whatsapp_cloud'

    render json: { error: 'Phone number management is only available for WhatsApp Cloud API inboxes' }, status: :unprocessable_entity
  end

  def phone_number_service
    Whatsapp::PhoneNumberManagementService.new(@inbox.channel)
  end

  def render_invalid_param(name)
    render json: { error: "Invalid #{name}" }, status: :unprocessable_entity
  end

  def render_meta_error(error)
    render json: { error: error.message }, status: :unprocessable_entity
  end
end
