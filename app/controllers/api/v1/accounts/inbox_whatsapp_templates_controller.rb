class Api::V1::Accounts::InboxWhatsappTemplatesController < Api::V1::Accounts::BaseController
  CATEGORIES = %w[MARKETING UTILITY AUTHENTICATION].freeze
  BUTTON_TYPES = %w[QUICK_REPLY URL PHONE_NUMBER].freeze
  HEADER_FORMATS = %w[TEXT IMAGE VIDEO DOCUMENT].freeze

  before_action :fetch_inbox
  before_action :validate_cloud_channel
  rescue_from Whatsapp::MetaApiError, with: :render_meta_error

  def create
    template = template_params
    return render_invalid_template unless valid_new_template?(template)

    render json: template_service.create(template), status: :created
  end

  def update
    template = template_params
    return render_invalid_template unless valid_template?(template)

    render json: template_service.update(params[:id], template)
  end

  def destroy
    template_service.delete(params[:id], params.require(:name))
    head :ok
  end

  def header_media
    render json: { handle: template_service.upload_header_media(params.require(:file)) }
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
      :name, :language, :category, :header_format, :header_text, :header_handle, :body_text, :footer_text,
      body_examples: [], buttons: [:type, :text, :url, :phone_number]
    )
  end

  def valid_new_template?(template)
    template[:name].to_s.match?(/\A[a-z0-9_]+\z/) && template[:language].present? && valid_template?(template)
  end

  def valid_template?(template)
    CATEGORIES.include?(template[:category]) &&
      template[:body_text].present? &&
      valid_header?(template) &&
      Array(template[:buttons]).all? { |button| BUTTON_TYPES.include?(button[:type]) && button[:text].present? }
  end

  def valid_header?(template)
    return true if template[:header_format].blank?
    return false unless HEADER_FORMATS.include?(template[:header_format])

    template[:header_format] == 'TEXT' || template[:header_handle].present?
  end

  def render_invalid_template
    render json: { error: 'Template requires a lowercase name, language, category, body text, a valid header and valid buttons' },
           status: :unprocessable_entity
  end

  def render_meta_error(error)
    render json: { error: error.message }, status: :unprocessable_entity
  end
end
