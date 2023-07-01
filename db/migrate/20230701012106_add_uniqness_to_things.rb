class AddUniqnessToThings < ActiveRecord::Migration[6.0]
  def change
    add_index :users, [:krakenLiveAPI], unique: true

    add_index :users,[:krakenLiveSecret], unique: true
    add_index :users, [:krakenTestAPI], unique: true
    add_index :users, [:krakenTestSecret], unique: true
    add_index :users, [:alpacaKey], unique: true
    add_index :users, [:alpacaSecret], unique: true
    add_index :users,  [:alpacaTestKey], unique: true
    add_index :users, [:alpacaTestSecret], unique: true
    add_index :users, [:oandaToken], unique: true
  end
end
