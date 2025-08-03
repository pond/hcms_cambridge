require "spec_helper.rb"

RSpec.describe User, type: :model do
  it "creates" do
    create(:user)
  end

  it "updates" do
    u = create(:user)
    u.update!(email: "fred.flintstone@bedrock.com")
  end

  it "deletes" do
    u = create(:user)
    u.destroy()
  end
end
