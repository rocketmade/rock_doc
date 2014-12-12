class CreateQuotes < ActiveRecord::Migration
  def change
    create_table :quotes do |t|
      t.string :body
      t.references :character, index: true

      t.timestamps null: false
    end
    add_foreign_key :quotes, :characters
  end
end
