class CreateServiceTickets < ActiveRecord::Migration[5.1]
  def change
    create_table :service_tickets do |t|
      t.integer :user_id
      t.string :url
      t.string :token

      t.timestamps
    end
  end
end
