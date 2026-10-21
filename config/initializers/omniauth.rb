# OmniAuth configuration
# Sets the full host URL for callbacks and proper redirect handling
OmniAuth.config.full_host = ENV.fetch('FRONTEND_URL', 'http://localhost:3000')

# Login through Auth0 Universal Login, where the installation enables social connections
# (Google, Microsoft, GitHub). Only emails Auth0 marks as verified identify a Chatwoot user,
# so nobody can claim an existing agent's email through an unverified sign up.
# Defined here because lib/ is eager loaded and would expect an Omniauth constant.
class OmniAuth::Strategies::Auth0 < OmniAuth::Strategies::OAuth2
  option :name, 'auth0'
  option :authorize_params, { scope: 'openid email profile' }

  uid { raw_info['sub'] }

  info do
    {
      email: (raw_info['email'] if raw_info['email_verified']),
      name: raw_info['name'],
      image: raw_info['picture']
    }
  end

  def raw_info
    @raw_info ||= access_token.get('/userinfo').parsed
  end

  # Must match the redirect_uri sent by the login button, which has no query string
  def callback_url
    full_host + callback_path
  end
end

Rails.application.config.middleware.use OmniAuth::Builder do
  provider :google_oauth2, ENV.fetch('GOOGLE_OAUTH_CLIENT_ID', nil), ENV.fetch('GOOGLE_OAUTH_CLIENT_SECRET', nil), {
    provider_ignores_state: true
  }
  provider :auth0, ENV.fetch('AUTH0_CLIENT_ID', nil), ENV.fetch('AUTH0_CLIENT_SECRET', nil), {
    client_options: {
      site: "https://#{ENV.fetch('AUTH0_DOMAIN', nil)}",
      authorize_url: '/authorize',
      token_url: '/oauth/token'
    },
    provider_ignores_state: true
  }
end
