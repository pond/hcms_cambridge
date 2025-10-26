source 'https://rubygems.org'
ruby '3.4.6'

gem 'rails', '>= 8', '< 9'

gem 'pg'
gem 'puma'

# Things that used to be in the standard library.
#
gem 'ostruct'

# Asset pipeline (sigh).
#
#   https://rubygems.org/gems/sass-rails
#   https://rubygems.org/gems/coffee-rails
#   https://rubygems.org/gems/uglifier
#
gem 'sass-rails'
gem 'coffee-rails'
gem 'uglifier'

# jQuery for JavaScript, SDoc formatted documentation.
#
#   https://rubygems.org/gems/sdoc
#   https://rubygems.org/gems/jquery-rails
#
gem 'jquery-rails'
gem 'sdoc'

# Device for Auth, with Device-integrated Redactor for editing.
#
#   https://rubygems.org/gems/devise
#
gem 'devise', '~> 4.9'

# Recaptcha used for e.g. the "booking" type pages.
#
#   https://rubygems.org/gems/recaptcha
#
gem 'recaptcha', '~> 5.20'

# Image uploads and support for the Redactor WYSIWYG-ish page editor.
#
#   https://rubygems.org/gems/fog-aws / https://github.com/fog/fog
#   https://rubygems.org/gems/carrierwave
#   https://rubygems.org/gems/mini_magick
#   https://rubygems.org/gems/redactor3_rails
#
gem 'fog-aws',         '~> 3.32'
gem 'carrierwave',     '~> 3.1'
gem 'mini_magick',     '~> 5.3'
gem 'redactor3_rails', git: 'https://github.com/pond/redactor3_rails.git', branch: 'feature/fix-js'

# Mail sending via MailGun.
#
#   https://rubygems.org/gems/mailgun-ruby
#
gem 'mailgun-ruby', '~> 1.3'

# Orderable pages.
#
#   https://rubygems.org/gems/acts_as_list
#
gem 'acts_as_list', '~> 1.2'

# State machines.
#
#   https://rubygems.org/gems/after_commit_everywhere
#   https://rubygems.org/gems/aasm
#
gem 'after_commit_everywhere', '~> 1.6'
gem 'aasm', '~> 5.5'

# Phone number validation.
#
#   https://rubygems.org/gems/phonelib
#
gem 'phonelib', '~> 0.10'

# Currency parsing and formatting.
#
#   https://rubygems.org/gems/money
#   https://rubygems.org/gems/monetize
#
gem 'money',    '~> 6.19'
gem 'monetize', '~> 1.13'

# Payments via Stripe.
#
#   https://rubygems.org/gems/stripe
#
gem 'stripe', '~> 17.0'

# Monitoring and alerting.
#
# * https://rubygems.org/gems/stackprof
#   https://rubygems.org/gems/sentry-ruby
#   https://rubygems.org/gems/sentry-rails
#   https://rubygems.org/gems/browser
#
gem 'stackprof'
gem 'sentry-ruby'
gem 'sentry-rails'
gem 'browser'

group :development do
  gem 'web-console'
  gem 'mailcatcher', '~> 0.10'
end

group :development, :test do
  gem 'debug'
  gem 'awesome_print'

  # Testing framework. Put here to avoid need for RAILS_ENV=test prefix on some
  # generators and tasks.
  #
  #   https://rubygems.org/gems/rspec-rails
  #
  gem 'rspec-rails', '~> 8.0'
  gem 'doggo',       '~> 1.4'

  # Generate sort-of-realistic test data easily.
  #
  #   https://rubygems.org/gems/faker
  #
  gem 'faker', '~> 3.5'
end

group :test do

  # Adds support for Capybara-driven system tests, with screenshots.
  #
  #   https://rubygems.org/gems/capybara
  #   https://rubygems.org/gems/capybara-screenshot
  #
  gem 'capybara',            '~> 3.40'
  gem 'capybara-screenshot', '~> 1.0'

  # Headless Chrome driver for Capybara.
  #
  #   https://rubygems.org/gems/cuprite
  #
  gem 'cuprite', '~> 0.17'

  # Fixture replacement.
  #
  #   https://rubygems.org/gems/factory_bot_rails
  #
  gem 'factory_bot_rails', '~> 6.5'

  # Code coverage reporting.
  #
  #   https://rubygems.org/gems/simplecov
  #
  gem 'simplecov', '~> 0.22', require: false
end
