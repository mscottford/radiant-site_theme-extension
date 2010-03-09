class AddPriceToSkins < ActiveRecord::Migration
  def self.up
    add_column :skins, :price, :string
  end

  def self.down
    remove_column :skins, :price
  end
end
