class Asaas::SubscriptionService
  attr_reader :account, :client

  def initialize(account)
    @account = account
    @client = Asaas::Client.new
  end

  def subscribe(total_numbers:, card_params:, holder_params:)
    total_numbers = total_numbers.to_i
    raise ArgumentError, 'Total de números deve ser pelo menos 2 para plano pago' if total_numbers < 2
    raise ArgumentError, 'Já existe uma assinatura ativa. Ajuste a quantidade de números em vez de assinar de novo.' if account.current_subscription.asaas_subscription_id.present?

    monthly_value_cents = AccountSubscription.calculate_monthly_amount(total_numbers)
    monthly_value_reais = (monthly_value_cents / 100.0).round(2)

    customer_id = find_or_create_customer(holder_params)

    subscription_payload = {
      customer: customer_id,
      billingType: 'CREDIT_CARD',
      value: monthly_value_reais,
      nextDueDate: Date.current.iso8601,
      cycle: 'MONTHLY',
      description: subscription_description(total_numbers),
      creditCard: {
        holderName: card_params[:holder_name],
        number: card_params[:number].to_s.gsub(/\D/, ''),
        expiryMonth: card_params[:expiry_month],
        expiryYear: card_params[:expiry_year],
        ccv: card_params[:ccv]
      },
      creditCardHolderInfo: {
        name: holder_params[:name] || card_params[:holder_name],
        email: holder_params[:email],
        cpfCnpj: holder_params[:cpf_cnpj].to_s.gsub(/\D/, ''),
        postalCode: holder_params[:postal_code].to_s.gsub(/\D/, ''),
        addressNumber: holder_params[:address_number] || '1',
        addressComplement: holder_params[:address_complement].presence,
        phone: holder_params[:phone].to_s.gsub(/\D/, '')
      }.compact
    }

    response = client.post('/subscriptions', subscription_payload)

    sub = account.current_subscription
    sub.update!(
      allowed_waba_count: total_numbers,
      status: 'active',
      monthly_amount_cents: monthly_value_cents,
      asaas_customer_id: customer_id,
      asaas_subscription_id: response['id'],
      credit_card_last4: card_params[:number].to_s.gsub(/\D/, '').last(4),
      credit_card_brand: response.dig('creditCard', 'creditCardBrand') || 'credit_card',
      next_due_date: response['nextDueDate']
    )

    sub
  end

  def update_slots(new_total_numbers)
    new_total_numbers = new_total_numbers.to_i
    sub = account.current_subscription

    if new_total_numbers <= 1
      # Downgrade para plano gratuito (1 número)
      cancel_existing_subscription(sub) if sub.asaas_subscription_id.present?
      sub.update!(
        allowed_waba_count: 1,
        status: 'free',
        monthly_amount_cents: 0,
        asaas_subscription_id: nil,
        credit_card_last4: nil,
        credit_card_brand: nil,
        next_due_date: nil
      )
      return sub
    end

    raise ArgumentError, 'Assine um plano com cartão antes de contratar mais números.' if sub.asaas_subscription_id.blank?

    new_cents = AccountSubscription.calculate_monthly_amount(new_total_numbers)
    new_reais = (new_cents / 100.0).round(2)

    client.put("/subscriptions/#{sub.asaas_subscription_id}", {
      value: new_reais,
      description: subscription_description(new_total_numbers),
      updatePendingPayments: true
    })

    sub.update!(
      allowed_waba_count: new_total_numbers,
      monthly_amount_cents: new_cents
    )
    sub
  end

  def update_card(card_params)
    sub = account.current_subscription
    raise StandardError, 'Nenhuma assinatura ativa encontrada' if sub.asaas_subscription_id.blank?

    card_payload = {
      creditCard: {
        holderName: card_params[:holder_name],
        number: card_params[:number].to_s.gsub(/\D/, ''),
        expiryMonth: card_params[:expiry_month],
        expiryYear: card_params[:expiry_year],
        ccv: card_params[:ccv]
      }
    }

    response = client.post("/subscriptions/#{sub.asaas_subscription_id}/creditCard", card_payload)

    sub.update!(
      credit_card_last4: card_params[:number].to_s.gsub(/\D/, '').last(4),
      credit_card_brand: response.dig('creditCard', 'creditCardBrand') || sub.credit_card_brand
    )
    sub
  end

  private

  def subscription_description(total_numbers)
    "Assinatura Cred Chat - #{total_numbers} números de WhatsApp"
  end

  def find_or_create_customer(holder_params)
    sub = account.current_subscription
    return sub.asaas_customer_id if sub.asaas_customer_id.present?

    customer_payload = {
      name: holder_params[:name] || account.name,
      email: holder_params[:email],
      cpfCnpj: holder_params[:cpf_cnpj].to_s.gsub(/\D/, ''),
      phone: holder_params[:phone].to_s.gsub(/\D/, ''),
      postalCode: holder_params[:postal_code].to_s.gsub(/\D/, ''),
      address: holder_params[:address].presence,
      addressNumber: holder_params[:address_number].presence,
      complement: holder_params[:address_complement].presence,
      province: holder_params[:province].presence,
      externalReference: "chatwoot_account_#{account.id}"
    }.compact

    response = client.post('/customers', customer_payload)
    response['id']
  end

  def cancel_existing_subscription(sub)
    client.delete("/subscriptions/#{sub.asaas_subscription_id}")
  rescue StandardError => e
    Rails.logger.warn("Falha ao cancelar assinatura no Asaas: #{e.message}")
  end
end
