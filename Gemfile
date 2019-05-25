source 'https://rubygems.org'
ruby '2.5.5'

# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem 'rails', '~> 4.2'
# Use postgresql as the database for Active Record
gem 'pg'
# Use CoffeeScript for .coffee assets and views
gem 'coffee-rails', '~> 4.1'
# See https://github.com/rails/execjs#readme for more supported runtimes
# gem 'therubyracer', platforms: :ruby
# Use Thin rather than Mongrel
gem 'thin'

# For Heroku only
gem 'rails_12factor'

# Asset pipeline (sigh)
gem 'sass-rails'
gem 'uglifier'

# Use jquery as the JavaScript library
gem 'jquery-rails'
# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
gem 'jbuilder', '~> 2.0'
# bundle exec rake doc:rails generates the API under doc/api.
gem 'sdoc', '~> 0.4.0', group: :doc

# Device for Auth, with Device-integrated Redactor for editing
gem 'devise'

# Imperavi Redactor via Redactor Rails gem, which uses Carrierwave for
# file uploads and MiniMagick for image processing; Fog AWS is used for
# Amazon S3 storage if on Heroku, else local filesystem will be used.
#
# We have to use 'master' branch of CarrierWave from GitHub because it's
# a mess of broken parts. See:
#
# https://github.com/carrierwaveuploader/carrierwave/issues/1608
# https://github.com/carrierwaveuploader/carrierwave/issues/1698
#
gem 'fog-aliyun', '~> 0.1.0' # Argh: https://github.com/CultivateLabs/storytime/issues/188
gem 'fog', require: 'fog/aws'
gem 'carrierwave', '~> 1.0.0' # github: 'carrierwaveuploader/carrierwave'
gem 'mini_magick'
gem 'redactor-rails'

# Orderable pages
# https://github.com/swanandp/acts_as_list
gem 'acts_as_list'

# Use Unicorn as the app server
# gem 'unicorn'

# Use Capistrano for deployment
# gem 'capistrano-rails', group: :development

group :development, :test do
  # Ruby 2 debugging
  gem 'byebug'

  # Access an IRB console on exception pages or by using <%= console %> in views
  gem 'web-console', '~> 2.0'

  # Catch e-mails on SMTP port 1025 and display a GUI for them on HTTP port 1080
  # https://mailcatcher.me
  gem 'mailcatcher'
end

