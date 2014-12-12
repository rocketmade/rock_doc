class CreateWorks < ActiveRecord::Migration
  def change
    create_table :works do |t|
      t.string :name
      t.integer :pulblication_year

      t.timestamps null: false
    end
  end
end
