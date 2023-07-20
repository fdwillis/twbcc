class RenameTakeProfitPl < ActiveRecord::Migration[6.0]
  def self.up
    rename_column :take_profits, :cost, :profitLoss
  end

  def self.down
  end
end
