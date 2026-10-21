class Api::V1::Accounts::CustomBillingController < Api::V1::Accounts::BaseController
  before_action :check_admin_authorization

  rescue_from Asaas::Client::ApiError, with: :render_asaas_error
  rescue_from StandardError, with: :render_standard_error

  def show
    sub = Current.account.current_subscription

    render json: {
      allowed_waba_count: sub.allowed_waba_count,
      connected_waba_count: Current.account.total_whatsapp_inboxes_count,
      status: sub.status,
      monthly_amount_cents: sub.monthly_amount_cents,
      credit_card_last4: sub.credit_card_last4,
      credit_card_brand: sub.credit_card_brand,
      next_due_date: sub.next_due_date,
      can_add_more: Current.account.can_add_whatsapp_number?
    }
  end

  def subscribe
    service = Asaas::SubscriptionService.new(Current.account)
    sub = service.subscribe(
      total_numbers: params[:total_numbers],
      card_params: card_params,
      holder_params: holder_params
    )

    render json: {
      message: 'Assinatura criada com sucesso!',
      allowed_waba_count: sub.allowed_waba_count,
      status: sub.status,
      monthly_amount_cents: sub.monthly_amount_cents
    }
  end

  def update_slots
    service = Asaas::SubscriptionService.new(Current.account)
    sub = service.update_slots(params[:total_numbers])

    render json: {
      message: 'Quantidade de números atualizada!',
      allowed_waba_count: sub.allowed_waba_count,
      monthly_amount_cents: sub.monthly_amount_cents
    }
  end

  def update_card
    service = Asaas::SubscriptionService.new(Current.account)
    sub = service.update_card(card_params)

    render json: {
      message: 'Cartão atualizado com sucesso!',
      credit_card_last4: sub.credit_card_last4,
      credit_card_brand: sub.credit_card_brand
    }
  end

  def invoices
    invoices = Current.account.billing_invoices.order(created_at: :desc).limit(20)
    render json: invoices
  end

  private

  def check_admin_authorization
    authorize Current.account, :update?
  end

  def card_params
    params.require(:card).permit(:holder_name, :number, :expiry_month, :expiry_year, :ccv)
  end

  def holder_params
    params.require(:holder).permit(:name, :email, :cpf_cnpj, :postal_code, :address_number, :phone)
  end

  def render_asaas_error(error)
    render json: { error: error.message }, status: :unprocessable_entity
  end

  def render_standard_error(error)
    render json: { error: error.message }, status: :unprocessable_entity
  end
end
