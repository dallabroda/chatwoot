class BillingInvoice < ApplicationRecord
  belongs_to :account

  validates :asaas_payment_id, presence: true
  validates :amount_cents, numericality: { greater_than_or_equal_to: 0 }
end
