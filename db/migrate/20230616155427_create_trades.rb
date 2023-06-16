class CreateTrades < ActiveRecord::Migration[6.0]
  def change
    create_table :trades do |t|
      t.string :uuid
      t.string :broker
      t.string :direction
      t.string :status
      t.string :finalTakeProfit
      t.belongs_to :user, null: false, foreign_key: true


      t.timestamps
    end
  end
end
