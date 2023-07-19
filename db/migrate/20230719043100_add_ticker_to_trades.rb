class AddTickerToTrades < ActiveRecord::Migration[6.0]
  def change
    add_column :trades, :ticker, :string
    add_column :take_profits, :ticker, :string
  end
end
