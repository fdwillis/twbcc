class CreateProducts < ActiveRecord::Migration[6.0]
  def change
    create_table :products do |t|
      t.string :country
      t.string :tags
      t.string :asin

      t.timestamps
    end
  end
end
