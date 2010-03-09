require 'zip/zip'
require 'zip/zipfilesystem'
require 'fileutils'
require 'hpricot'

class Skin < ActiveRecord::Base
	has_attached_file :image, :styles => { :thumb => "100x100", :small => "200x200", :medium => "300x300", :large => "500x500" }
	has_attached_file :archive, :path => ":rails_root/lib/:class/:attachment/:id/:basename.:extension", :url => ":rails_root/lib/:class/:attachment/:id/:basename.:extension"

  belongs_to :created_by, :class_name => 'User'
  belongs_to :updated_by, :class_name => 'User'
  has_many :sites

  validates_uniqueness_of :name

	def unzip_and_process_skin
		#archive_name = self.archive_file_name.delete('.zip')
		archive_name = self.archive_file_name.chomp(File.extname(self.archive_file_name))		
		archive = Zip::ZipFile.open(self.archive.path, Zip::ZipFile::CREATE)

    begin
      archive.get_entry("#{archive_name}/#{archive_name}.yml")
    rescue Errno::ENOENT => e
      raise "The file you tried to upload appears invalid. Please check it, and try again."
    end

		conf = YAML::parse(archive.read("#{archive_name}/#{archive_name}.yml"))

    if Skin.exists?(:name => conf.select("/name")[0].value)
      self.delete
      raise ActiveRecord::RecordNotSaved
    else
		  # Open a copy of the skin shot and "paperclip" it to our skin model
		  skin_shot_path = File::join RAILS_ROOT, "public", "images", "admin", "skin_shots"
      Dir.mkdir(skin_shot_path) unless File.directory?(skin_shot_path)
		  img = File.new("#{skin_shot_path}/#{archive_name}.png", "w+")
		  img << archive.read("#{archive_name}/#{archive_name}.png")
		  self.image = img
		  self.name = conf.select("/name")[0].value
		  self.description = conf.select("/description")[0].value
      self.skin_type = conf.select("/type")[0].value
      self.price = conf.select("/price")[0].value
		  self.save!
		  File.delete(img.path)
    end
	end

  # Activate Skin on user's site.  
  #----------------------------------------------------------------------------
	def activate_on(site, user)

    # Determine if this site already has an active skin. If it does raise an error and 
    # tell the user to deactivate their current skin before activating a new one.
    if site.skin
      raise "You already have an active skin: <strong>#{site.skin.name}</strong>. Deactive your current skin, before activating a new skin."
    end

    deactivate_on(site)
		skin_name = self.archive_file_name.chomp(File.extname(self.archive_file_name))		
		skin_zip = Zip::ZipFile.open(self.archive.path, Zip::ZipFile::CREATE)				

		# Extract skin zip contents. We will remove this folder when were done.
		extract_point = File::join RAILS_ROOT, "lib", "skins", "extracts"
  
    # Make sure this skin hasn't already been extracted. If it has delete it.
    FileUtils.rm_rf(File.join(extract_point, site.id.to_s)) if File.exist?(File.join(extract_point, site.id.to_s))

    # Create a new folder in lib/skins/extracts and dump the contents of the skin zip in there.
		skin_zip.each { |e|
				fpath = File.join(extract_point, site.id.to_s, e.name)
				FileUtils.mkdir_p(File.dirname(fpath))
				skin_zip.extract(e, fpath)
		}


    if Layout.exists?(:name => "#{skin_name}", :site_id => site.id)
		  layout = Layout.first(:conditions => {:name => "#{skin_name}", :site_id => site.id})
      layout.content = skin_zip.read("#{skin_name}/layout.html")
      layout.save!
    else
      # Create the default layout
		  layout = Layout.new(
			  :name => "#{skin_name}", 
			  :content => skin_zip.read("#{skin_name}/layout.html"),
			  :site_id => site.id, 
			  :created_by_id => user.id
		  )
      layout.save!
		end

    if Layout.exists?(:name => "stylesheet", :site_id => site.id)
		  style = Layout.first(:conditions => {:name => "stylesheet", :site_id => site.id})
      style.content = '<r:content />'
      style.save!      
    else
		  # Create the style layout
		  style = Layout.new(
		  	:name => "stylesheet", 
			  :content => '<r:content />', 
			  :content_type => 'text/css', 
			  :site_id => site.id,
			  :created_by_id => user.id
		  )
      style.save!
    end

		# Create a default homepage and stylesheet
		homepage = Page.new
		stylesheet = Page.new

		homepage.title = 'Home'
		homepage.layout_id = layout.id
		homepage.slug = '/'
		homepage.breadcrumb = "Home"
		homepage.description = ''
		homepage.keywords = ''
		homepage.created_by_id = user.id
		homepage.status_id = 100
		homepage.site_id = site.id
    homepage.skin_page = true
		homepage.save!

		stylesheet.title = "style.css"
		stylesheet.layout_id = style.id
		stylesheet.slug = 'style.css'
		stylesheet.breadcrumb = "style.css"
		stylesheet.description = ''
		stylesheet.keywords = ''
		stylesheet.created_by_id = user.id
		stylesheet.status_id = 100
		stylesheet.site_id = site.id
		stylesheet.parent_id = homepage.id
    stylesheet.skin_page = true
		stylesheet.save!		

    # Create a empty stylesheet named "style" for skin style overrides, etc.
  	PagePart.create!(
  		:name => 'body',
 			:content => "",
 			:page_id => stylesheet.id
   	)

		# Add Skin images to assets  
		Dir.foreach("#{extract_point}/#{site.id.to_s}/#{skin_name}/images") { |image|
			next if image == '.'
			next if image == '..'
			img = File.open("#{extract_point}/#{site.id.to_s}/#{skin_name}/images/#{image}", "r")
			asset = Asset.new
			asset.asset = img
			asset.title = image.chomp(File.extname(image))
			asset.created_by_id = user.id
			asset.site_id = site.id
       asset.skin_image = true
			asset.save!
		}

		# Create the page parts  
		Dir.foreach("#{extract_point}/#{site.id.to_s}/#{skin_name}/parts") { |part|
			next if part == '.'
			next if part == '..'
			File.open("#{extract_point}/#{site.id.to_s}/#{skin_name}/parts/#{part}", "r") do |file|
				contents = ""
				while line = file.gets
           if line =~ /(<r:assets:.+\/>)/
             line = insert_asset_url(line, site.id)
           end
					contents << line
				end
			
				part = PagePart.new(
					:name => part.chomp(File.extname(part)),
					:content => contents,
					:page_id => homepage.id,
          :skin_page_part =>  true
				)
				part.save!
			end
		}

		# Create page snippets  
		Dir.foreach("#{extract_point}/#{site.id.to_s}/#{skin_name}/snippets") { |snippet|
			next if snippet == '.'
			next if snippet == '..'
			File.open("#{extract_point}/#{site.id.to_s}/#{skin_name}/snippets/#{snippet}", "r") do |file|
				contents = ""
				while line = file.gets
           if line =~ /(<r:assets:.+\/>)/
             line = insert_asset_url(line, site.id)
           end
           line.gsub!(/\{site_path\}/, site.hostname)     
           line.gsub!(/\{site_id\}/, site.id.to_s)     
					contents << line
				end
		
				snippet = Snippet.new(
					:name => snippet.chomp(File.extname(snippet)),
					:content => contents,
					:site_id => site.id,
					:created_by_id => user.id,
          :skin_snippet => true
				)
				snippet.save!
			end
		}

		# Create default pages.  
		Dir.foreach("#{extract_point}/#{site.id.to_s}/#{skin_name}/pages") { |page|
			next if page == '.'
			next if page == '..'

			File.open("#{extract_point}/#{site.id.to_s}/#{skin_name}/pages/#{page}", "r") do |file|
				contents = ""
				while line = file.gets
           if line =~ /(<r:assets:.+\/>)/
             line = insert_asset_url(line, site.id)
           end
           line.gsub!(/\{site_path\}/, site.hostname)     
           line.gsub!(/\{site_id\}/, site.id.to_s)     
					contents << line
				end
        		
        cpage = Page.new
	  		cpage.title = page
	   		cpage.layout_id = layout.id
	   		cpage.slug = page
	   		cpage.breadcrumb = page
	   		cpage.description = ''
	   		cpage.keywords = ''
	   		cpage.created_by_id = user.id
	   		cpage.status_id = 100
	   		cpage.site_id = site.id
	   		cpage.parent_id = homepage.id
        cpage.skin_page = true
	   		cpage.save!	

	  		part = PagePart.new(
	   			:name => 'body',
	   			:content => contents,
	   			:page_id => cpage.id,
          :skin_page_part => true
	   		)
	   		part.save!

			end


		}
	
  	# Add Skin styles  
    Dir.foreach("#{extract_point}/#{site.id.to_s}/#{skin_name}/styles") { |sheet|
	   	next if sheet == '.'
	   	next if sheet == '..'
      next if sheet == nil

	   	# Create a style page.
	   	File.open("#{extract_point}/#{site.id.to_s}/#{skin_name}/styles/#{sheet}", "r") do |file|
	   		contents = ""
	   		while line = file.gets
      		contents << line
	   		end
       
        ssheet = Page.new
	  		ssheet.title = sheet
	   		ssheet.layout_id = style.id
	   		ssheet.slug = sheet
	   		ssheet.breadcrumb = sheet.split(/\./)[0]
	   		ssheet.description = ''
	   		ssheet.keywords = ''
	   		ssheet.created_by_id = user.id
	   		ssheet.status_id = 100
	   		ssheet.site_id = site.id
	   		ssheet.parent_id = homepage.id
        ssheet.skin_page = true
	   		ssheet.save!	
    
	  		part = PagePart.new(
	   			:name => 'body',
	   			:content => contents,
	   			:page_id => ssheet.id,
          :skin_page_part => true
	   		)
	   		part.save!
	   	end
	  }	


		# Remove skin zip content  
		FileUtils.rm_r("#{extract_point}/#{site.id.to_s}/#{skin_name}")

    # Tell the site what skin we're using
    self.sites << site
	end

  # Deactive Skin on current site.  
  #----------------------------------------------------------------------------
	def deactivate_on(site)
		#Layout.delete_all(["site_id = ? AND name = ?", site.id, "#{self.name.downcase}"])
		#Layout.delete_all(["site_id = ? AND name = ?", site.id, "stylesheet"])

		pages = Page.find(:all, :conditions => ["site_id = ?", site.id])
		pages.each { |page|
      page.parts.each { |part|
        PagePart.delete(part.id)
      }
  		Page.delete(page.id)
		}

    #snippets = Snippet.find(:all, :conditions => ["site_id = ? AND skin_snippet = ?", site.id, true])
    #snippets.each { |snippet|
    #  Snippet.destroy(snippet.id)
    #}

    #assets = Asset.find(:all, :conditions => ["site_id = ? AND skin_image = ?", site.id, true])
    #assets.each { |asset|
    #  Asset.destroy(asset.id)
    #}

		Layout.delete_all(["site_id = ?", site.id])
    Asset.delete_all(["site_id = ? AND skin_image = ?", site.id, true])
    #Page.destroy_all(["site_id = ?", site.id])
    Snippet.delete_all(["site_id = ?", site.id])

    # Site no longer has this skin.
    self.sites.delete(site)
	end

  # Simple Search  
  #----------------------------------------------------------------------------
  def self.search(search, page)
    paginate :per_page => 12, :page => page,
             :conditions => ['name like ? || description like ?', "%#{search}%", "%#{search}%"], :order => 'name'
  end


  # Parse radius tags.
  #----------------------------------------------------------------------------
  def insert_asset_url(line, site_id)
    original_line = line
    matches = []
    doc = Hpricot(line).search('img').each do |img|
      r_tag = img.attributes['src']
      r_tag.gsub(/(["'])(?:\\\1|.)*?\1/) { |match| 
        matches.push(match)
      }
    end

    asset_title = matches[0][1..-2]
    asset_size = matches[1][1..-2]
    asset = Asset.first(:conditions => {:title => asset_title, :site_id => site_id})
    if asset_size != nil
      original_line.gsub!(/(<r:assets:url.+\/>)(?=")/, "/assets/#{asset.id}/#{asset_title}_#{asset_size}#{File.extname(asset.asset_file_name)}")
    else
      original_line.gsub!(/(<r:assets:url.+\/>)(?=")/, "/assets/#{asset.id}/#{asset_title}#{File.extname(asset.asset_file_name)}")
    end
  end

  def trim(str)
    str.chop!
    str.slice!(1, str.length)
  end

end
