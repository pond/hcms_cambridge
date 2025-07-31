source 'https://rubygems.org'
ruby '3.4.5'

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

# Orderable pages.
#
#   https://rubygems.org/gems/acts_as_list
#
gem 'acts_as_list', '~> 1.2'

# Phone number validation.
#
#   https://rubygems.org/gems/phony
#
gem 'phony', '~> 2.22'

group :development do
  gem 'web-console'
  gem 'mailcatcher', '~> 0.10'
end

group :development, :test do
  gem 'debug'
  gem 'awesome_print'
end
