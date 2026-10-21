class CreateBillingInvoices < ActiveRecord::Migration[7.2]
  def change
    create_table :billing_invoices do |t|
      t.references :account, null: false, foreign_key: true

      # ID do pagamento no Asaas (pay_xxx)
      t.string :asaas_payment_id, null: false, index: true

      # Valor em centavos e status da cobrança
      t.integer :amount_cents, null: false
      t.string :status, null: false # 'CONFIRMED', 'RECEIVED', 'OVERDUE', etc.

      # Link do recibo/fatura oficial do Asaas
      t.string :invoice_url

      # Datas de vencimento e pagamento
      t.date :due_date
      t.datetime :payment_date

      t.timestamps
    end
  end
end
