class Api::V1::Accounts::InboxWhatsappTemplatesController < Api::V1::Accounts::BaseController
  CATEGORIES = %w[MARKETING UTILITY AUTHENTICATION].freeze
  BUTTON_TYPES = %w[QUICK_REPLY URL PHONE_NUMBER].freeze

  before_action :fetch_inbox
  before_action :validate_cloud_channel

  def create
    template = template_params
    return render_invalid_template unless valid_template?(template)

    result = template_service.create(template)
    render json: result, status: :created
  rescue Whatsapp::MetaApiError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def destroy
    template_service.delete(params[:name])
    head :ok
  rescue Whatsapp::MetaApiError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def fetch_inbox
    @inbox = Current.account.inboxes.find(params[:inbox_id])
    authorize @inbox, :update?
  end

  def validate_cloud_channel
    return if @inbox.whatsapp? && @inbox.channel.provider == 'whatsapp_cloud'

    render json: { error: 'Template management is only available for WhatsApp Cloud API inboxes' }, status: :unprocessable_entity
  end

  def template_service
    Whatsapp::TemplateManagementService.new(@inbox.channel)
  end

  def template_params
    params.require(:template).permit(
      :name, :language, :category, :header_text, :body_text, :footer_text,
      body_examples: [], buttons: [:type, :text, :url, :phone_number]
    )
  end

  def valid_template?(template)
    template[:name].to_s.match?(/\A[a-z0-9_]+\z/) &&
      template[:language].present? &&
      CATEGORIES.include?(template[:category]) &&
      template[:body_text].present? &&
      Array(template[:buttons]).all? { |button| BUTTON_TYPES.include?(button[:type]) && button[:text].present? }
  end

  def render_invalid_template
    render json: { error: 'Template requires a lowercase name, language, category, body text and valid buttons' },
           status: :unprocessable_entity
  end
end
