class CreateLegs < ActiveRecord::Migration[6.0]
  def change
    create_table :legs do |t|
      t.belongs_to :user, null: false, foreign_key: true
      t.string :people

      t.timestamps
    end
  end
end
