class AccountSubscription < ApplicationRecord
  belongs_to :account

  STATUSES = %w[free active past_due canceled].freeze
  PRICE_PER_ADDITIONAL_NUMBER_CENTS = 6000 # R$ 60,00
  TRIAL_DAYS = 7
  TRIAL_WABA_LIMIT = 2

  validates :status, inclusion: { in: STATUSES }
  validates :allowed_waba_count, numericality: { greater_than_or_equal_to: 1 }

  def self.calculate_monthly_amount(total_numbers)
    return 0 if total_numbers.to_i <= 1

    (total_numbers.to_i - 1) * PRICE_PER_ADDITIONAL_NUMBER_CENTS
  end

  def can_connect_whatsapp?(current_connected_count)
    return false if past_due?

    current_connected_count < effective_waba_limit
  end

  # Numbers usable right now: what was paid for, or the trial allowance while the trial runs.
  # An overdue subscription falls back to the free number until the payment goes through.
  def effective_waba_limit
    return allowed_waba_count if paid?

    base_limit = past_due? ? 1 : allowed_waba_count
    in_trial? ? [base_limit, TRIAL_WABA_LIMIT].max : base_limit
  end

  def paid?
    asaas_subscription_id.present? && status == 'active'
  end

  def trial_ends_at
    trial_started_at&.+(TRIAL_DAYS.days)
  end

  def in_trial?
    trial_started_at.present? && Time.current < trial_ends_at
  end

  def trial_expired?
    trial_started_at.present? && !in_trial?
  end

  # The trial starts with the first number ever connected and is never restarted.
  def start_trial!
    update!(trial_started_at: Time.current) if trial_started_at.nil?
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
