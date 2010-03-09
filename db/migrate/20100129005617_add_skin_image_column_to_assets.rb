class AddSkinImageColumnToAssets < ActiveRecord::Migration
  def self.up
    add_column :pages, :skin_page, :boolean, :default => false
    add_column :assets, :skin_image, :boolean, :default => false
    add_column :snippets, :skin_snippet, :boolean, :default => false
    add_column :page_parts, :skin_page_part, :boolean, :default => false
  end

  def self.down
    remove_column :pages, :skin_page
    remove_column :assets, :skin_image
    remove_column :snippets, :skin_snippet
    remove_column :page_parts, :skin_page_part
  end
end
