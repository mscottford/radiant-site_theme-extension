class AddUpdatedByToSkins < ActiveRecord::Migration
  def self.up
    add_column :skins, :updated_by_id, :integer
  end

  def self.down
    remove_column :skins, :updated_by_id
  end
end
