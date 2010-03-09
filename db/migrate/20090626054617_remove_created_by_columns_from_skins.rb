class RemoveCreatedByColumnsFromSkins < ActiveRecord::Migration
  def self.up
		remove_column :skins, :created_by_id
		remove_column :skins, :updated_by_id
		remove_column :skins, :content_type
  end

  def self.down
		add_column :skins, :created_by_id, :integer
		add_column :skins, :updated_by_id, :integer
		add_column :skins, :content_type, :string
  end
end
