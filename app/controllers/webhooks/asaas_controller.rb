class Webhooks::AsaasController < ActionController::API
  before_action :validate_webhook_token

  def process_payload
    event = params[:event]
    payment = params[:payment]

    case event
    when 'PAYMENT_CONFIRMED', 'PAYMENT_RECEIVED'
      handle_payment_success(payment)
    when 'PAYMENT_OVERDUE'
      handle_payment_overdue(payment)
    when 'SUBSCRIPTION_DELETED'
      handle_subscription_deleted(params[:subscription])
    else
      Rails.logger.info("Asaas Webhook: Evento não tratado #{event}")
    end

    head :ok
  rescue StandardError => e
    Rails.logger.error("Erro no processamento do webhook Asaas: #{e.message}")
    head :ok
  end

  private

  def validate_webhook_token
    token = ENV.fetch('ASAAS_WEBHOOK_TOKEN', nil)
    return if token.blank?

    header_token = request.headers['asaas-access-token']
    head :unauthorized unless ActiveSupport::SecurityUtils.secure_compare(token, header_token.to_s)
  end

  def handle_payment_success(payment)
    return if payment.blank?

    sub = find_subscription(payment)
    return unless sub

    sub.update!(status: 'active')

    invoice = sub.account.billing_invoices.find_or_initialize_by(asaas_payment_id: payment['id'])
    invoice.update!(
      amount_cents: (payment['value'].to_f * 100).round,
      status: payment['status'] || 'CONFIRMED',
      invoice_url: payment['invoiceUrl'],
      due_date: payment['dueDate'],
      payment_date: payment['paymentDate'] || Time.current
    )
  end

  def handle_payment_overdue(payment)
    return if payment.blank?

    sub = find_subscription(payment)
    sub&.update!(status: 'past_due')
  end

  def handle_subscription_deleted(subscription_data)
    sub_id = subscription_data&.dig('id') || params.dig('payment', 'subscription')
    return if sub_id.blank?

    sub = AccountSubscription.find_by(asaas_subscription_id: sub_id)
    sub&.update!(status: 'canceled', allowed_waba_count: 1, monthly_amount_cents: 0)
  end

  def find_subscription(payment)
    if payment['subscription'].present?
      AccountSubscription.find_by(asaas_subscription_id: payment['subscription'])
    elsif payment['customer'].present?
      AccountSubscription.find_by(asaas_customer_id: payment['customer'])
    end
  end
end
