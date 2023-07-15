class AddToTrades < ActiveRecord::Migration[6.0]
  def change
    add_column :trades, :stripePI, :string
  end
end
