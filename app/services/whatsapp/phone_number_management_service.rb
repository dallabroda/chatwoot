# Ownership verification and Cloud API registration of a channel's phone number
class Whatsapp::PhoneNumberManagementService
  API_VERSION = 'v22.0'.freeze

  def initialize(whatsapp_channel)
    @whatsapp_channel = whatsapp_channel
  end

  # code_method: SMS or VOICE; Meta sends a 6-digit code to the number
  def request_code(code_method, language)
    post('request_code', code_method: code_method, language: language)
  end

  def verify_code(code)
    post('verify_code', code: code)
  end

  # The PIN becomes the number's two-step verification PIN, so keep it for later re-registrations
  def register(pin)
    post('register', messaging_product: 'whatsapp', pin: pin)
    @whatsapp_channel.provider_config['verification_pin'] = pin
    @whatsapp_channel.save!
  end

  def deregister
    post('deregister')
  end

  private

  def post(action, body = {})
    response = HTTParty.post(phone_number_url(action), headers: @whatsapp_channel.api_headers, body: body.to_json)
    raise Whatsapp::MetaApiError.from_response(response) unless response.success?

    response.parsed_response
  end

  def phone_number_url(action)
    base_url = ENV.fetch('WHATSAPP_CLOUD_BASE_URL', 'https://graph.facebook.com')
    "#{base_url}/#{API_VERSION}/#{@whatsapp_channel.provider_config['phone_number_id']}/#{action}"
  end
end
