class CreateBrands < ActiveRecord::Migration[6.0]
  def change
    create_table :brands do |t|
      t.string :title
      t.string :tags
      t.string :countries
      t.string :images
      t.string :categories
      t.string :amazonCategory

      t.timestamps
    end
  end
end
