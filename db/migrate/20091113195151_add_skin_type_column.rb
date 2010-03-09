class AddSkinTypeColumn < ActiveRecord::Migration
  def self.up
    add_column :skins, :skin_type, :string
  end

  def self.down
    remove_column :skins, :skin_type
  end
end
