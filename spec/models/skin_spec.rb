require File.dirname(__FILE__) + '/../spec_helper'

describe Skin do
  before(:each) do
    @skin = Skin.new
  end

  it "should be valid" do
    @skin.should be_valid
  end
end
