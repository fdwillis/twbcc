class AddOandaListToUsers < ActiveRecord::Migration[6.0]
  def change
    add_column :users, :oandaList, :string
  end
end
