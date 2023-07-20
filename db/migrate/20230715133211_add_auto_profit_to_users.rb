class AddAutoProfitToUsers < ActiveRecord::Migration[6.0]
  def change
    add_column :users, :autoProfitPay, :boolean
  end
end
