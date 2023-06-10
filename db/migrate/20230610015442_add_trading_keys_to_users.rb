class AddTradingKeysToUsers < ActiveRecord::Migration[6.0]
  def change
    add_column :users, :krakenLiveAPI, :string
    add_column :users, :krakenLiveSecret, :string
    add_column :users, :krakenTestAPI, :string
    add_column :users, :krakenTestSecret, :string
    add_column :users, :alpacaKey, :string
    add_column :users, :alpacaSecret, :string
    add_column :users, :alpacaTestKey, :string
    add_column :users, :alpacaTestSecret, :string
    add_column :users, :oandaToken, :string
  end
end
