class AddUniqnessToThings < ActiveRecord::Migration[6.0]
  def up
    change_column :users, [:krakenLiveAPI], unique: true

    change_column :users,[:krakenLiveSecret], unique: true
    change_column :users, [:krakenTestAPI], unique: true
    change_column :users, [:krakenTestSecret], unique: true
    change_column :users, [:alpacaKey], unique: true
    change_column :users, [:alpacaSecret], unique: true
    change_column :users,  [:alpacaTestKey], unique: true
    change_column :users, [:alpacaTestSecret], unique: true
    change_column :users, [:oandaToken], unique: true
  end

  def down
    remove_index :users, [:krakenLiveAPI], unique: true

    remove_index :users,[:krakenLiveSecret], unique: true
    remove_index :users, [:krakenTestAPI], unique: true
    remove_index :users, [:krakenTestSecret], unique: true
    remove_index :users, [:alpacaKey], unique: true
    remove_index :users, [:alpacaSecret], unique: true
    remove_index :users,  [:alpacaTestKey], unique: true
    remove_index :users, [:alpacaTestSecret], unique: true
    remove_index :users, [:oandaToken], unique: true
  end
end
