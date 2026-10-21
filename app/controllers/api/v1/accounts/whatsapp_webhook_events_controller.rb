class Api::V1::Accounts::WhatsappWebhookEventsController < Api::V1::Accounts::BaseController
  before_action :check_admin_authorization?

  def index
    render json: { payload: Whatsapp::WebhookEventLog.new(Current.account).events }
  end
end
