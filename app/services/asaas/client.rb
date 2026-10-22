class Asaas::Client
  class ApiError < StandardError; end

  def initialize
    @api_key = ENV.fetch('ASAAS_API_KEY', nil)
    @environment = ENV.fetch('ASAAS_ENVIRONMENT', 'sandbox')
  end

  def base_url
    if @environment.to_s.downcase == 'production'
      'https://api.asaas.com/v3'
    else
      'https://sandbox.asaas.com/api/v3'
    end
  end

  def post(path, body = {})
    request(:post, path, body)
  end

  def put(path, body = {})
    request(:put, path, body)
  end

  def get(path, query = {})
    request(:get, path, nil, query)
  end

  def delete(path)
    request(:delete, path)
  end

  private

  def request(method, path, body = nil, query = nil)
    raise ApiError, 'ASAAS_API_KEY is not configured in .env' if @api_key.blank?

    options = {
      headers: {
        'access_token' => @api_key,
        'Content-Type' => 'application/json',
        'User-Agent' => 'Chatwoot-SaaS'
      }
    }
    options[:body] = body.to_json if body.present?
    options[:query] = query if query.present?

    response = HTTParty.public_send(method, "#{base_url}#{path}", options)
    parsed = response.parsed_response

    unless response.success?
      error_msg = extract_error_message(parsed) || "Asaas API Error (#{response.code})"
      raise ApiError, error_msg
    end

    parsed
  end

  def extract_error_message(parsed)
    return unless parsed.is_a?(Hash)

    if parsed['errors'].is_a?(Array)
      parsed['errors'].map { |e| e['description'] }.join(', ')
    elsif parsed['message'].present?
      parsed['message']
    end
  end
end
