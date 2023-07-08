class AddTraderTokenToUsers < ActiveRecord::Migration[6.0]
  def change
    add_column :users, :tradierToken, :string
  end
end
