class AddToCustominquiries < ActiveRecord::Migration[6.0]
  def change
     add_column :custominquiries, :memberType, :string
     add_column :custominquiries, :interval, :string
  end
end
