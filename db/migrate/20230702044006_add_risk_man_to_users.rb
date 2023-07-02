class AddRiskManToUsers < ActiveRecord::Migration[6.0]
  def change
    add_column :users, :perEntry, :float
    add_column :users, :reduceBy, :float
    add_column :users, :profitTrigger, :float
    add_column :users, :maxRisk, :float
    add_column :users, :allowMarketOrder, :string
  end
end
