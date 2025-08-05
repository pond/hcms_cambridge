require "spec_helper.rb"

RSpec.describe PageType, type: :model do
  it "has a basic sanity check in addition to coverage-in-passing via system tests" do
    Page::ORDERED_PAGE_TYPES.each do | type |
      pt = PageType.new(type)

      expect(pt.internal_name).to eql(type)
      expect(pt.human_name   ).to be_a(String)
    end
  end
end
