class CreateJsonData < ActiveRecord::Migration[6.0]
  def change
    create_table :json_data do |t|
      t.json :payload
      t.json :params

      t.timestamps
    end
  end
end
