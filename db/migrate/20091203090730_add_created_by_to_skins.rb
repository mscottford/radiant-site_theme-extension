class AddCreatedByToSkins < ActiveRecord::Migration
  def self.up
    add_column :skins, :created_by_id, :integer
  end

  def self.down
    remove_column :skins, :created_by_id
  end
end
