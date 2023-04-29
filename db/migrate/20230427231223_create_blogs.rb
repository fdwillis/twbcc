class CreateBlogs < ActiveRecord::Migration[6.0]
  def change
    create_table :blogs do |t|
      t.string :title, unique: true
      t.text :body
      t.string :asins
      t.string :tags
      t.string :images
      t.belongs_to :user, null: false, foreign_key: true

      t.timestamps
    end
  end
end
