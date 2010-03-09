class CreateSkins < ActiveRecord::Migration
  def self.up
    create_table :skins do |t|
      t.string :name, :limit => 100
			t.string :description
      t.text :content
      t.datetime :created_at
      t.datetime :updated_at
      t.integer :created_by_id
      t.integer :updated_by_id
      t.string :content_type
      t.integer :lock_version
      t.integer :site_id
    end
  end

  def self.down
    drop_table :skins
  end
end
