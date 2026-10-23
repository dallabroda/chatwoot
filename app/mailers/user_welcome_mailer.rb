class UserWelcomeMailer < ApplicationMailer
  def welcome(user)
    return unless smtp_config_set_or_development?

    @resource = user
    @account = params[:account]
    brand_name = GlobalConfig.get('BRAND_NAME')['BRAND_NAME'] || 'Chatwoot'
    mail(to: user.email, subject: I18n.t('devise_mailer.welcome.subject', brand_name: brand_name)) do |format|
      format.html { render 'devise/mailer/welcome' }
    end
  end
end
