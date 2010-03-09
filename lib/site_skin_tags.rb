module SiteSkinTags
  include Radiant::Taggable

  desc "Creates an context for the skin functionality" 
  tag 'skin' do |tag|
    tag.expand
  end

  # skin:each
  #----------------------------------------------------------------------------
	desc "Iterate over all skin in the system, optionally sorted by the field specified by 'order', or constrained by 'where'."
  tag 'skin:each' do |tag|
    attr = tag.attr.symbolize_keys
    order=attr[:order] || 'name ASC'
    where=attr[:where]
    result = []
    skin = Skin.find(:all, :conditions => where, :order => order)
    skin.each do |skin|
      tag.locals.skin = skin
      result << tag.expand
    end
    result
  end

  # skin:name
  #----------------------------------------------------------------------------  
 	desc "Renders the HTML-escaped name of the current skin loaded by <r:skin> or <r:skin:each>"
  tag 'skin:name' do |tag|
    skin = tag.locals.skin
    html_escape skin.name ? skin.name : "none"
  end

  # skin:id
  #----------------------------------------------------------------------------  
 	desc "Renders the HTML-escaped id of the current skin loaded by <r:skin> or <r:skin:each>"
  tag 'skin:id' do |tag|
    skin = tag.locals.skin
    html_escape skin.id ? skin.id : "none"
  end


  # skin:image
  #----------------------------------------------------------------------------
  desc "Renders an <img> element for the current skin loaded by <r:skin> or <r:skin:each>.. Optionally takes 'size'."
  tag 'skin:image' do |tag|
	  attr = tag.attr.symbolize_keys
    skin = tag.locals.skin
    %{<img src="#{skin.image.url(attr[:size])}", alt="#{skin.description}" />}
  end

end
