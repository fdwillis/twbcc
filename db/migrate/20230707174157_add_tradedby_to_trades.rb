class AddTradedbyToTrades < ActiveRecord::Migration[6.0]
  def change
    add_column :trades, :traderID, :string
    add_column :take_profits, :traderID, :string
  end
end
