# Raised for failed Evolution API calls, carrying its error body
class Whatsapp::EvolutionApiError < StandardError
  def self.from_response(response)
    body = response.parsed_response
    message = body.is_a?(Hash) ? Array(body['message']).flatten.join(', ').presence || body['error'] : nil

    new(message.presence || "Evolution API request failed (#{response.code})")
  end
end
