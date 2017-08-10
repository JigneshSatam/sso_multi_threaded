class CreateServiceTickets < ActiveRecord::Migration[5.1]
  def change
    create_table :service_tickets do |t|
      t.integer :model_instance_id
      t.string :url
      t.string :token

      t.timestamps
    end
  end
end
