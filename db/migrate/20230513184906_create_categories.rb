class CreateCategories < ActiveRecord::Migration[6.0]
  def change
    create_table :categories do |t|
      t.string :title
      t.string :description
      t.string :tags
      t.string :images
      t.boolean :featured
      t.boolean :published

      t.timestamps
    end
  end
end
