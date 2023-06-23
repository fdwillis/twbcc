class AddAutorizedListToUsers < ActiveRecord::Migration[6.0]
  def change
    add_column :users, :authorizedList, :string
  end
end
