class Api::V1::Accounts::WhatsappSharedAssetsController < Api::V1::Accounts::BaseController
  before_action :check_admin_authorization?

  def index
    render json: { payload: Whatsapp::SharedAssetsService.new(Current.account).perform }
  end
end
