# == Schema Information
#
# Table name: channel_api
#
#  id                    :bigint           not null, primary key
#  additional_attributes :jsonb
#  hmac_mandatory        :boolean          default(FALSE)
#  hmac_token            :string
#  identifier            :string
#  secret                :string
#  webhook_url           :string
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  account_id            :integer          not null
#
# Indexes
#
#  index_channel_api_on_hmac_token  (hmac_token) UNIQUE
#  index_channel_api_on_identifier  (identifier) UNIQUE
#

class Channel::Api < ApplicationRecord
  include Channelable

  self.table_name = 'channel_api'
  EDITABLE_ATTRS = [:webhook_url, :hmac_mandatory, { additional_attributes: {} }].freeze

  has_secure_token :identifier
  has_secure_token :hmac_token
  include WebhookSecretable
  validate :ensure_valid_agent_reply_time_window
  validates :webhook_url, length: { maximum: Limits::URL_LENGTH_LIMIT }
  EVOLUTION_IDENTITY_KEYS = %w[connection_type evolution_instance_name risk_accepted_at risk_accepted_by].freeze

  before_update :preserve_evolution_identity
  after_create_commit -> { account.current_subscription.start_trial! }, if: :evolution_qr?
  after_destroy :cleanup_evolution_instance, if: :evolution_qr?

  def name
    'API'
  end

  def evolution_qr?
    additional_attributes&.dig('connection_type') == 'evolution_qr'
  end

  private

  # Settings forms replace the whole hash; never let an edit drop or alter what makes this a QR number,
  # otherwise it would silently stop counting towards the plan's number limit.
  def preserve_evolution_identity
    previous = additional_attributes_in_database || {}
    return unless previous['connection_type'] == 'evolution_qr'

    current = additional_attributes || {}
    current = current.merge(previous.slice(*EVOLUTION_IDENTITY_KEYS))
    current['connection_state'] ||= previous['connection_state']
    self.additional_attributes = current
  end

  def cleanup_evolution_instance
    instance_name = additional_attributes&.dig('evolution_instance_name')
    return if instance_name.blank?

    Whatsapp::EvolutionConnectionService.new(self, instance_name).delete_instance
  rescue StandardError => e
    Rails.logger.error "[Evolution] Failed to delete instance #{instance_name} on channel destroy: #{e.message}"
  end

  private

  def ensure_valid_agent_reply_time_window
    return if additional_attributes['agent_reply_time_window'].blank?
    return if additional_attributes['agent_reply_time_window'].to_i.positive?

    errors.add(:agent_reply_time_window, 'agent_reply_time_window must be greater than 0')
  end
end
