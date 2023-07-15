class AddToTakeProfits < ActiveRecord::Migration[6.0]
  def change
    add_column :take_profits, :stripePI, :string
  end
end
