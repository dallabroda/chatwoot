class AddCourtesyToAccountSubscriptions < ActiveRecord::Migration[7.2]
  def change
    # Time-boxed extra numbers granted by CredTech (e.g. 5 free numbers for 30 days); expires on its own
    add_column :account_subscriptions, :courtesy_waba_count, :integer
    add_column :account_subscriptions, :courtesy_until, :datetime
  end
end
