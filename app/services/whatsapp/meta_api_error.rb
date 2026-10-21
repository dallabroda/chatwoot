# Raised for failed Graph API calls, carrying Meta's user-facing explanation
class Whatsapp::MetaApiError < StandardError
  def self.from_response(response)
    error = response.parsed_response.is_a?(Hash) ? response.parsed_response['error'] : nil
    return new("WhatsApp API request failed (#{response.code})") if error.blank?

    new(error['error_user_msg'].presence || error['message'])
  end
end
