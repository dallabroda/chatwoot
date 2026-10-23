class DeviseOverrides::PasswordsController < Devise::PasswordsController
  include AuthHelper
  include MfaAuthenticationHelper

  skip_before_action :require_no_authentication, raise: false
  skip_before_action :authenticate_user!, raise: false

  def create
    unless params[:redirect_url].nil? || params[:redirect_url].is_a?(String)
      return render json: { error: 'Invalid redirect_url' }, status: :unprocessable_entity
    end

    @user = User.from_email(params[:email])
    @user&.send_reset_password_instructions(redirect_url: params[:redirect_url], sso_account_id: params.permit(:sso_account_id)[:sso_account_id])
    build_response(I18n.t('messages.reset_password'), 200)
  end

  def update
    # params: reset_password_token, password, password_confirmation
    original_token = params[:reset_password_token]
    reset_password_token = Devise.token_generator.digest(self, :reset_password_token, original_token)
    @recoverable = User.find_by(reset_password_token: reset_password_token)
    # Every invite/reset email issues a new token and voids the previous one, so old links end up here
    return render_invalid_reset_token unless @recoverable&.reset_password_period_valid?
    return render_invalid_password unless reset_password_and_confirmation(@recoverable)
    return render_mfa_sign_in_required if mfa_sign_in_required?(@recoverable)

    send_auth_headers(@recoverable)
    render partial: 'devise/auth', formats: [:json], locals: { resource: @recoverable }
  end

  private

  def reset_password_and_confirmation(recoverable)
    # A password that fails validation must come back as a readable error, not a server error
    return false unless recoverable.reset_password(params[:password], params[:password_confirmation])

    recoverable.confirm unless recoverable.confirmed? # confirm if user resets password without confirming anytime before
    recoverable.update!(reset_password_token: nil, confirmation_token: nil, reset_password_sent_at: nil)
  end

  def render_invalid_reset_token
    render json: { message: I18n.t('errors.password_reset.invalid_token'), error_code: 'invalid_token' },
           status: :unprocessable_entity
  end

  def render_invalid_password
    render json: { message: @recoverable.errors.full_messages.to_sentence, error_code: 'invalid_password' },
           status: :unprocessable_entity
  end

  def build_response(message, status)
    render json: {
      message: message
    }, status: status
  end
end

DeviseOverrides::PasswordsController.prepend_mod_with('DeviseOverrides::PasswordsController')
