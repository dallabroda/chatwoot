class AddTrialStartedAtToAccountSubscriptions < ActiveRecord::Migration[7.2]
  def up
    add_column :account_subscriptions, :trial_started_at, :datetime

    # Accounts that already had numbers before trials existed: the trial counts from their first number.
    execute <<~SQL.squish
      UPDATE account_subscriptions s
      SET trial_started_at = first_numbers.first_at
      FROM (
        SELECT account_id, MIN(created_at) AS first_at FROM (
          SELECT account_id, created_at FROM channel_whatsapp
          UNION ALL
          SELECT account_id, created_at FROM channel_api
          WHERE additional_attributes->>'connection_type' = 'evolution_qr'
        ) numbers
        GROUP BY account_id
      ) first_numbers
      WHERE s.account_id = first_numbers.account_id AND s.trial_started_at IS NULL
    SQL
  end

  def down
    remove_column :account_subscriptions, :trial_started_at
  end
end
