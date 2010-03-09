# Uncomment this if you reference any of your controllers in activate
require_dependency 'application_controller'

# Going to need this to add regions to the extension interface
require 'ostruct'

class SiteSkinsExtension < Radiant::Extension
  version "1.0"
  description "Custom themes for Radiant Sites"
  url ""
  
   define_routes do |map|
     map.namespace :admin, :member => { :remove => :get } do |admin|
			 admin.resources :skins
		 end
		 map.activate_skin 'admin/skins/activate/:id', :controller => 'admin/skins', :action => 'activate'
		 map.deactivate_skin 'admin/skins/deactivate/:id', :controller => 'admin/skins', :action => 'deactivate'
     map.search 'admin/skins/search', :controller => 'admin/skins', :action => 'search_skins'
   end
  
  def activate
    admin.nav[:content] << admin.nav_item(:look, "Look & Feel", "/admin/skins")
    admin.nav[:content].reverse!
    UserActionObserver.instance.send :add_observer!, Skin

    # Include custom tags
    Page.send :include, SiteSkinTags

    # This adds information to the Radiant interface.
    Radiant::AdminUI.class_eval do
      attr_accessor :skins
    end

    # initialize regions for skin (which was created above)
    admin.skins = load_default_skin_regions

    # Provide the ability to replace regions...
    # Don't like how the regions are setup? Hack it without changing this extension's code
    # Be forewarned, this allows you to completely change the UI
    Radiant::AdminUI::RegionSet.class_eval do
      def replace(region=nil, partial=nil)
        raise ArgumentError, "You must specify a region and a partial" unless region and partial
        self[region].replace([partial])
      end
    end
  end

  private

  # Define the regions to be used in the views and partials
  def load_default_skin_regions
    returning OpenStruct.new do |skin|
      skin.index = Radiant::AdminUI::RegionSet.new  do |index|
        index.main.concat %w{skin_list}
        index.sidebar.concat %w{sidebar_boxes}
      end
      skin.search_skins = Radiant::AdminUI::RegionSet.new  do |search_skins|
        search_skins.main.concat %w{skin_list}
        search_skins.sidebar.concat %w{sidebar_boxes}
      end
    end
  end
  
end
