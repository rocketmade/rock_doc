class CreateCharacters < ActiveRecord::Migration
  def change
    create_table :characters do |t|
      t.string :name
      t.references :work, index: true

      t.timestamps null: false
    end
    add_foreign_key :characters, :works
  end
end
