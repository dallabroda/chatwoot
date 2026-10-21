class AccountSubscription < ApplicationRecord
  belongs_to :account

  STATUSES = %w[free active past_due canceled].freeze
  PRICE_PER_ADDITIONAL_NUMBER_CENTS = 6000 # R$ 60,00

  validates :status, inclusion: { in: STATUSES }
  validates :allowed_waba_count, numericality: { greater_than_or_equal_to: 1 }

  def self.calculate_monthly_amount(total_numbers)
    return 0 if total_numbers.to_i <= 1

    (total_numbers.to_i - 1) * PRICE_PER_ADDITIONAL_NUMBER_CENTS
  end

  def can_connect_whatsapp?(current_connected_count)
    return false if past_due?

    current_connected_count < allowed_waba_count
  end

  def free_tier?
    status == 'free' && allowed_waba_count <= 1
  end

  def active?
    %w[free active].include?(status)
  end

  def past_due?
    status == 'past_due'
  end
end
