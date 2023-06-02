class CreateClosedTrades < ActiveRecord::Migration[6.0]
  def change
    create_table :closed_trades do |t|
      t.string :entry
      t.string :protection
      t.string :entryStatus
      t.string :protectionStatus

      t.timestamps
    end
  end
end
