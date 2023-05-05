class AddCountryToBlogs < ActiveRecord::Migration[6.0]
  def change
    add_column :blogs, :country, :string
  end
end
