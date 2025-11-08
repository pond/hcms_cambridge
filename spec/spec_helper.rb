# https://github.com/colszowka/simplecov#getting-started
#
require "simplecov"

SimpleCov.configure do
  load_profile "rails"
  add_filter "spec"
end

SimpleCov.start

# ==============================================================================

require "debug"
require "capybara/cuprite"
require "capybara/rspec"
require "capybara-screenshot/rspec"

ENV["RAILS_ENV"] ||= "test"

require File.expand_path("../../config/environment", __FILE__)
abort("The Rails environment is running in production mode!") if Rails.env.production?

# Get Warden running in test mode.
#
#   https://github.com/wardencommunity/warden/blob/da64f1ab4ae1f4147a65f8bbe2d7571180f2e38b/lib/warden/test/helpers.rb
#
include Warden::Test::Helpers
Warden.test_mode!

require "rspec/rails"

# Rails.application.eager_load!
# Zeitwerk::Loader.eager_load_all()

Dir[Rails.root.join("spec", "support", "**", "*.rb")].each { |f| require f }

begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  puts e.to_s.strip
  exit 1
end

# Things like 'Faker::Address.full_address' tend to respect this setting.
#
Faker::Config.locale = "en-NZ"

# Some tests may make assumptions about currency precision or other formatting
# rules; they should use #spechelp_format_money or an equivalent.
#
SUPPORTED_TEST_CURRENCIES = ["NZD", "EUR", "GBP", "JPY", "TND"]

# https://thoughtbot.com/blog/acceptance-tests-with-subdomains
#
Capybara.configure do |config|
  config.always_include_port = true
  config.default_normalize_ws = true # ("have_text..." will squish whitespace arising from markup into single spaces)
end

# https://github.com/mattheworiordan/capybara-screenshot#better-looking-html-screenshots
#
Capybara::Screenshot.prune_strategy = :keep_last_run

# https://github.com/rspec/rspec-rails/issues/1897#issuecomment-410781898
#
Capybara.server = :puma, { Silent: true }

# https://github.com/mattheworiordan/capybara-screenshot/issues/227
#
Dir.mkdir(Capybara.save_path) unless Dir.exist?(Capybara.save_path)

RSpec.configure do |config|
  config.disable_monkey_patching!
  config.raise_errors_for_deprecations!
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!

  config.include FactoryBot::Syntax::Methods
  config.include ActiveSupport::Testing::TimeHelpers
  config.include ActiveJob::TestHelper
  config.include ActiveSupport::NumberHelper

  config.color                            = true
  config.tty                              = true
  config.order                            = :random
  config.fixture_paths                    = ["#{::Rails.root}/spec/fixtures"]
  config.use_transactional_fixtures       = true
  config.shared_context_metadata_behavior = :apply_to_host_groups

  Kernel.srand(config.seed)

  config.before :each, type: :system do |example|
    if example&.metadata&.dig(:js) == true
      spechelp_use_chrome()
    else
      driven_by(:rack_test, options: { respect_data_method: false })
    end
  end

  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end
end

# https://makandracards.com/makandra/16117-how-to-clear-cookies-in-capybara-tests-both-selenium-and-rack-test
#
def spechelp_quick_logout
  if Capybara.current_session.driver.respond_to?(:clear_cookies) # Cuprite
    Capybara.current_session.driver.clear_cookies()
  else
    browser = Capybara.current_session.driver.browser

    if browser.respond_to?(:clear_cookies) # Rack::MockSession
      browser.clear_cookies()
    elsif browser.respond_to?(:manage) && browser.manage.respond_to?(:delete_all_cookies) # Selenium::WebDriver
      browser.manage.delete_all_cookies()
    else
      raise "Don't know how to clear cookies!"
    end
  end
end

def spechelp_use_chrome
  driven_by(:cuprite)

  cuprite  = Capybara.current_session.driver
  headless = ENV["FULL_CHROME"].blank?
  slowmo   = headless ? nil : 0.15

  # https://github.com/rubycdp/ferrum#customization
  #
  cuprite.options.merge!(
    window_size:               [1280, 1280],
    flatten:                   false,
    pending_connection_errors: false,
    inspector:                 true,
    headless:                  headless,
    slowmo:                    slowmo,
    browser_options:           {
      "no-sandbox":               nil,
      "disable-smooth-scrolling": nil,
    },
  )

  spechelp_log_out_via_cookie_clearing()
end

# Verify that there's a particular message of a given type in the flash.
#
# +type+::    Type of flash, e.g. :notice, :alert
# +message+:: Message expected to be present - uses substring match
#
def spechelp_check_flash(type, message)
  expect(page).to have_css("section.messages p.#{type}", text: message)
end

# Like Capybara "select(something, from: "identifier"), but where "something" is
# the relevant option's unique submitted *value*, not the visible text.
#
# +value+:: Value of <option> entry within the selection list to select.
# +from+:: ID of the selection list to target (note - HTML ID, not name). Don't
#          include a leading "#" here.
#
def spechelp_select(value, from:)
  find(:css, "select[id='#{ from }'] option[value='#{ value }']").select_option()
end

# Exactly as #helper_select, but unselects (de-selects) the identified option.
#
def spechelp_unselect(value, from:)
  find(:css, "select[id='#{ from }'] option[value='#{ value }']").unselect_option()
end

# Fill the given text into the Redactor rich text editor.
#
def spechelp_fill_in_redactor(body, for_type: 'page')
  editor = find(:css, ".redactor_container .redactor-in")
  editor.click()

  # Wait for input focus to be assigned before "typing".
  #
  expect(page).to have_css(".redactor_container .redactor-in:focus")

  # Strange race condition; even waiting for the container to have-text
  # "body", fast execution fails with the body being empty. The only
  # way around this that I could find was a hacky sleep via go-slow.
  #
  editor.send_keys(body)

  # Must wait for those keys to be processed by Redactor and written to
  # the hidden textarea field for the page body.
  #
  expect(page).to have_field("#{for_type}_body", visible: false, with: /#{body}/)
end

# Given a String which might contain HTML or entities, return the plain text
# equivalent with tags stripped and entities converted to characters.
#
# White space is stripped off the ends of the string, but white space anomalies
# (such as multiple spaces) might appear inside the string depending upon the
# exact formatting of any now-stripped markup.
#
# +rich_text+:: Input text to convert.
#
def spechelp_strip_markup(rich_text)
  plain_text = CGI.unescapeHTML(ActionView::Base.full_sanitizer.sanitize(rich_text))
  return plain_text.strip()
end

# Format a currency amount for known currencies using a hard-coded method, in
# order to catch any "holding it wrong" errors for the Money gem. Assumes an
# English-like locale, so decimals are "." not "," and the position of e.g. an
# EUR symbol is before, not after the numerical amount.
#
def spechelp_format_money(amount, currency)
  raise "Unsupported currency #{currency.inspect}" unless SUPPORTED_TEST_CURRENCIES.include?(currency)

  c_to_sym = {
    "NZD" => "$",
    "GBP" => "£",
    "EUR" => "€",
    "JPY" => "¥",
    "TND" => "د.ت",
  }

  c_to_d_p = {
    "NZD" => 2,
    "GBP" => 2,
    "EUR" => 2,
    "JPY" => 0,
    "TND" => 3,
  }

  sym = c_to_sym[currency]
  d_p = c_to_d_p[currency]

  amount = number_to_rounded(
    BigDecimal(amount) / 10.pow(d_p),
    precision:  d_p,
    round_mode: :half_up,
    delimiter:  I18n.t("number.format.delimiter"),
  )

  if currency == 'TND'
    "#{amount} #{sym}"
  else
    "#{sym}#{amount}"
  end
end

# Log in via UI navigation. Pass a user (else one is made by default factory).
# The logged in User is returned, for convenience.
#
def spechelp_log_in(user = nil)
  user ||= create(:user)

  visit(new_admin_user_session_path())

  fill_in("admin_user_email",    with: user.email)
  fill_in("admin_user_password", with: Constants::DEFAULT_VALID_PASSWORD)
  click_on("Log in")

  if Page.none?
    expect(page).to have_current_path(admin_pages_path())
  else
    expect(page).to have_current_path(admin_page_path(Page.home))
  end

  expect(page).to have_css("section.messages p.notice", text: "Signed in")

  return user
end

# Log out via hackery rather than via navigating the UI, for speed.
#
def spechelp_log_out_via_cookie_clearing
  if Capybara.current_session.driver.respond_to?(:clear_cookies) # Headless Chrome
    Capybara.current_session.driver.clear_cookies()
  else
    browser = Capybara.current_session.driver.browser

    if browser.respond_to?(:clear_cookies) # Rack driver
      browser.clear_cookies()
    elsif browser.respond_to?(:manage) && browser.manage.respond_to?(:delete_all_cookies) # Selenium driver
      browser.manage.delete_all_cookies()
    else
      raise "Cannot clear cookes with this driver"
    end
  end
end

# Call after an e-mail should have been delivered. Returns a Data object with
# members "email" (raw object), "text" (decoded text), "html" (decoded HTML).
#
# Expects one message with two parts, one text, one HTML - *unless* named
# parameter "count" is set to a number > 1. In _that_ case the integer gives
# the number of expected messages and the return value is an array of decoded
# data objects containing the e-mail contents. Order is probably undefined, so
# tests should try not to rely upon it - see #spechelper_find_in_decoded.
#
def spechelp_decode_multipart(count: 1)
  perform_enqueued_jobs() # (from ActiveJob::TestHelper)

  expect(ActionMailer::Base.deliveries.count).to eq(count)

  result = ActionMailer::Base.deliveries.map do | email |
    expect(email).to be_multipart()
    expect(email.parts.size).to eql(2)

    text_part = email.parts.find { |part| part.content_type.include?('text/plain') }
    html_part = email.parts.find { |part| part.content_type.include?('text/html') }

    expect(text_part).to be_present
    expect(html_part).to be_present

    Data
      .define(:email, :text, :html)
      .new(
        email: email,
        text:  text_part.body.decoded,
        html:  html_part.body.decoded
      )
  end

  return count == 1 ? result.first : result
end

# Helper for #spechelp_decode_multipart - in an array of results, returns the
# entry with an exactly matching single 'to' e-mail address, else +nil+.
#
def spechelper_find_in_decoded(messages, to:)
  messages.find { | msg | msg.email.to == [to] }
end

# Given HTML from an ActionMailer-sent e-mail along with an e-mail address,
# expect to find a "mailto" link for that address. Optional "body" and
# "subject" contents can be checked for too.
#
def spechelp_check_mailto(html:, email:, body: nil, subject: nil)
  helper = Object.new.extend(ActionView::Helpers::UrlHelper)

  expect(html).to include(helper.mail_to(email, subject: subject, body: body))
end

# Similar to #spechelp_check_mailto, but for telephone number links in e-mails.
#
def spechelp_check_tel(html:, phone:)
  helper = Object.new.extend(ActionView::Helpers::UrlHelper)

  expect(html).to include(helper.link_to(phone, "tel:#{phone.gsub(' ', '%20')}"))
end

# Wait for a default jQuery animation to complete.
#
# TODO: Currently, this a very simple implementation! Just assumes a 400ms
# TODO: animation and near-immediate execution.
#
def spechelp_wait_for_animation
  sleep 0.5 # (see TODO notes above!)
end
