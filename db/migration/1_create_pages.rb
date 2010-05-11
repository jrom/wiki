class CreatePages < ActiveRecord::Migration
  def self.up
    create_table :pages do |t|
      t.integer :id
      t.string :url, :unique => true, :null => false
      t.string :title
      t.text :body

      t.timestamps
    end
    add_index :pages, :url, :unique => true
  end
  def self.down
    drop_table :pages
    remove_index :pages, :url
  end
end
