class CreateLastSignals < ActiveRecord::Migration[6.0]
  def change
    create_table :last_signals do |t|
      t.string :direction
      t.float :open
      t.float :close
      t.float :high
      t.float :low
      t.string :ticker

      t.timestamps
    end
  end
end
