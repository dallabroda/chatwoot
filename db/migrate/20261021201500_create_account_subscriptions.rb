class CreateAccountSubscriptions < ActiveRecord::Migration[7.2]
  def change
    create_table :account_subscriptions do |t|
      t.references :account, null: false, foreign_key: true, index: { unique: true }

      # Limite de números de WhatsApp (padrão: 1 gratuito)
      t.integer :allowed_waba_count, default: 1, null: false

      # Status da assinatura: 'free', 'active', 'past_due', 'canceled'
      t.string :status, default: 'free', null: false

      # Valor mensal em centavos (ex: R$ 60,00 = 6000 centavos)
      t.integer :monthly_amount_cents, default: 0, null: false

      # Referências no gateway Asaas
      t.string :asaas_customer_id, index: true
      t.string :asaas_subscription_id, index: true

      # Metadados do cartão de crédito (sem dados sensíveis)
      t.string :credit_card_last4
      t.string :credit_card_brand

      # Data da próxima cobrança
      t.date :next_due_date

      t.timestamps
    end
  end
end
