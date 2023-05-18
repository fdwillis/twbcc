class CreateCustominquiries < ActiveRecord::Migration[6.0]
  def change
    create_table :custominquiries do |t|
      t.string :email
      t.string :phone

      t.timestamps
    end
  end
end
