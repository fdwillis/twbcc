class AddStatsToTrades < ActiveRecord::Migration[6.0]
  def change
    add_column :trades, :cost, :float, default: 0
    add_column :trades, :profitable, :boolean, default: false
    add_column :trades, :profitCollected, :boolean, default: false
    add_column :trades, :stripeInvoiceID, :string
    
    add_column :take_profits, :cost, :float, default: 0
  end
end
