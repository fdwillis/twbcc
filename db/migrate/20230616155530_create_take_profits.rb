class CreateTakeProfits < ActiveRecord::Migration[6.0]
  def change
    create_table :take_profits do |t|
      t.string :uuid
      t.string :broker
      t.string :direction
      t.string :status
      t.belongs_to :trade, null: false, foreign_key: true
      t.belongs_to :user, null: false, foreign_key: true

      t.timestamps
    end
  end
end
