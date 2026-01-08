require "spec_helper.rb"

RSpec.describe "Admin - first time setup" do
  it "redirects root to login" do
    visit "/"

    expect(page).to have_current_path(new_admin_user_session_path())
  end

  context "admin user sign-up" do
    it "allows initial user setup" do
      visit("/")
      click_on("Sign up") # (the link)

      expect(page).to have_current_path(new_admin_user_registration_path())

      fill_in("admin_user_email",                 with: "fred.flintstone@bedrock.com")
      fill_in("admin_user_password",              with: Constants::DEFAULT_VALID_PASSWORD)
      fill_in("admin_user_password_confirmation", with: Constants::DEFAULT_VALID_PASSWORD)
      click_on("Sign up")

      expect(page).to have_current_path(admin_pages_path())
      expect(page).to have_css("section.messages p.notice", text: "Welcome!")

      expect(User.count).to eql(1)
      expect(User.first.email).to eql("fred.flintstone@bedrock.com")
      expect(User.first.valid_password?(Constants::DEFAULT_VALID_PASSWORD)).to eql(true)
    end

    it "rejects other signups" do
      create(:user)
      visit(new_admin_user_registration_path())

      expect(page).to have_current_path(new_admin_user_session_path())
      expect(page).to have_css("section.messages p.alert", text: "not allowed")
    end
  end

  context "admin user routine" do
    it "allows sign-in" do
      u = create(:user)
      visit(new_admin_user_session_path())

      fill_in("admin_user_email",    with: u.email)
      fill_in("admin_user_password", with: Constants::DEFAULT_VALID_PASSWORD)
      click_on("Log in")

      expect(page).to have_current_path(admin_pages_path())
      expect(page).to have_css("section.messages p.notice", text: "Signed in")
    end

    it "supports a forgotten password cycle" do
      u = create(:user)
      visit(new_admin_user_session_path())

      click_on("Forgot your password?")
      fill_in("admin_user_email", with: u.email)
      click_on("Send me password reset instructions")

      perform_enqueued_jobs() # (from ActiveJob::TestHelper)

      expect(ActionMailer::Base.deliveries.count).to eq(1)

      email = ActionMailer::Base.deliveries.last
      body  = email.body.decoded

      expect(body).to include("Hello #{u.email}")

      reset_link_str = email.body.decoded.match(/\"(http\:\/\/.*?)\"/)[1]
      reset_link_uri = URI.parse(reset_link_str)
      path_and_query = reset_link_uri.request_uri

      visit(path_and_query)

      fill_in("admin_user_password",              with: "thequickbrownfox")
      fill_in("admin_user_password_confirmation", with: "thequickbrownfox")
      click_on("Change my password")

      expect(page).to have_current_path(admin_pages_path())
      expect(page).to have_css("section.messages p.notice", text: "Your password has been changed")
      expect(u.reload.valid_password?("thequickbrownfox")).to eql(true)
    end
  end

  context "validations" do
    it "sign up" do
      visit(new_admin_user_registration_path())
      click_on("Sign up")

      expect(page).to have_css("div.field_error_messages", text: "Email must be provided")
      expect(page).to have_css("div.field_error_messages", text: "Password must be provided")

      fill_in("admin_user_password", with: "1234")
      click_on("Sign up")

      expect(page).to_not have_css("div.field_error_messages", text: "Password must be provided")
      expect(page).to     have_css("div.field_error_messages", text: "Password is too short (minimum is 8 characters)")

      fill_in("admin_user_email",                 with: "fred.flintstone@bedrock.com")
      fill_in("admin_user_password",              with: "1234567890")
      fill_in("admin_user_password_confirmation", with: Constants::DEFAULT_VALID_PASSWORD)
      click_on("Sign up")

      expect(page).to_not have_css("div.field_error_messages", text: "Email must be provided")
      expect(page).to_not have_css("div.field_error_messages", text: "Password must be provided")
      expect(page).to     have_css("div.field_error_messages", text: "Password confirmation doesn't match Password")
    end

    it "sign in" do
      visit(new_admin_user_session_path())
      click_on("Log in")

      expect(page).to have_css("section.messages p.alert", text:  "Invalid email or password")

      fill_in("admin_user_email",    with: "a@b.com")
      fill_in("admin_user_password", with: "1234567890")
      click_on("Log in")

      expect(page).to have_css("section.messages p.alert", text:  "Invalid email or password")
    end

    it "reset password" do
      u = create(:user)
      visit(new_admin_user_session_path())

      click_on("Forgot your password?")
      fill_in("admin_user_email", with: u.email)
      click_on("Send me password reset instructions")

      perform_enqueued_jobs() # (from ActiveJob::TestHelper)

      email          = ActionMailer::Base.deliveries.last
      body           = email.body.decoded
      reset_link_str = email.body.decoded.match(/\"(http\:\/\/.*?)\"/)[1]
      reset_link_uri = URI.parse(reset_link_str)
      path_and_query = reset_link_uri.request_uri

      visit(path_and_query)

      click_on("Change my password")

      expect(page).to have_css("div.field_error_messages", text: "Password must be provided")

      fill_in("admin_user_password",              with: "1234567890")
      fill_in("admin_user_password_confirmation", with: Constants::DEFAULT_VALID_PASSWORD)
      click_on("Change my password")

      expect(page).to_not have_css("div.field_error_messages", text: "Password must be provided")
      expect(page).to     have_css("div.field_error_messages", text: "Password confirmation doesn't match Password")

      fill_in("admin_user_password",              with: "1234")
      fill_in("admin_user_password_confirmation", with: "1234")
      click_on("Change my password")

      expect(page).to_not have_css("div.field_error_messages", text: "Password must be provided")
      expect(page).to_not have_css("div.field_error_messages", text: "Password confirmation doesn't match Password")
      expect(page).to     have_css("div.field_error_messages", text: "Password is too short (minimum is 8 characters)")
    end
  end
end
