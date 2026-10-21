class Whatsapp::TemplateManagementService
  API_VERSION = 'v22.0'.freeze
  MEDIA_HEADER_FORMATS = %w[IMAGE VIDEO DOCUMENT].freeze

  def initialize(whatsapp_channel)
    @whatsapp_channel = whatsapp_channel
  end

  # Submits the template to Meta for approval and refreshes the cached template list.
  def create(template)
    body = request_body(template).merge(name: template[:name], language: template[:language])
    request(:post, "#{business_account_id}/message_templates", body)
  end

  # Meta keeps name and language; only category and components can change.
  def update(template_id, template)
    request(:post, template_id, request_body(template))
  end

  def delete(template_id, name)
    request(:delete, "#{business_account_id}/message_templates", nil, query: { hsm_id: template_id, name: name })
  end

  # Media headers are approved from a sample file uploaded through the Resumable Upload API;
  # the returned handle goes into the header example.
  def upload_header_media(file)
    session = request_without_sync(:post, "#{GlobalConfigService.load('WHATSAPP_APP_ID', '')}/uploads", nil,
                                   query: { file_name: file.original_filename, file_length: file.size, file_type: file.content_type })
    response = HTTParty.post(graph_url(session['id']),
                             headers: { 'Authorization' => "OAuth #{api_key}", 'file_offset' => '0' }, body: file.read)
    raise Whatsapp::MetaApiError.from_response(response) unless response.success?

    response['h']
  end

  private

  def request(method, path, body, query: nil)
    result = request_without_sync(method, path, body, query: query)
    @whatsapp_channel.sync_templates
    result
  end

  def request_without_sync(method, path, body, query: nil)
    options = { headers: @whatsapp_channel.api_headers, query: query }
    options[:body] = body.to_json if body
    response = HTTParty.public_send(method, graph_url(path), options)
    raise Whatsapp::MetaApiError.from_response(response) unless response.success?

    response.parsed_response
  end

  def graph_url(path)
    "#{ENV.fetch('WHATSAPP_CLOUD_BASE_URL', 'https://graph.facebook.com')}/#{API_VERSION}/#{path}"
  end

  def business_account_id
    @whatsapp_channel.provider_config['business_account_id']
  end

  def api_key
    @whatsapp_channel.provider_config['api_key']
  end

  def request_body(template)
    {
      category: template[:category],
      components: [header(template), body(template), footer(template), buttons(template)].compact
    }
  end

  def header(template)
    if MEDIA_HEADER_FORMATS.include?(template[:header_format])
      return { type: 'HEADER', format: template[:header_format], example: { header_handle: [template[:header_handle]] } }
    end
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
