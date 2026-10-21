class Whatsapp::TemplateManagementService
  API_VERSION = 'v22.0'.freeze

  def initialize(whatsapp_channel)
    @whatsapp_channel = whatsapp_channel
  end

  # Submits the template to Meta for approval and refreshes the cached template list.
  def create(template)
    response = HTTParty.post(templates_url, headers: @whatsapp_channel.api_headers, body: request_body(template).to_json)
    raise Whatsapp::MetaApiError.from_response(response) unless response.success?

    @whatsapp_channel.sync_templates
    response.parsed_response
  end

  def delete(name)
    response = HTTParty.delete(templates_url, headers: @whatsapp_channel.api_headers, query: { name: name })
    raise Whatsapp::MetaApiError.from_response(response) unless response.success?

    @whatsapp_channel.sync_templates
  end

  private

  def templates_url
    base_url = ENV.fetch('WHATSAPP_CLOUD_BASE_URL', 'https://graph.facebook.com')
    "#{base_url}/#{API_VERSION}/#{@whatsapp_channel.provider_config['business_account_id']}/message_templates"
  end

  def request_body(template)
    {
      name: template[:name],
      language: template[:language],
      category: template[:category],
      components: [header(template), body(template), footer(template), buttons(template)].compact
    }
  end

  def header(template)
    return if template[:header_text].blank?

    { type: 'HEADER', format: 'TEXT', text: template[:header_text] }
  end

  def body(template)
    component = { type: 'BODY', text: template[:body_text] }
    component[:example] = { body_text: [template[:body_examples]] } if template[:body_examples].present?
    component
  end

  def footer(template)
    return if template[:footer_text].blank?

    { type: 'FOOTER', text: template[:footer_text] }
  end

  def buttons(template)
    return if template[:buttons].blank?

    { type: 'BUTTONS', buttons: template[:buttons].map { |button| button.to_h.compact_blank } }
  end
end
