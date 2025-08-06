require_relative 'boot'

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Hcms
  class Application < Rails::Application

    config.load_defaults 6.1

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Load this here so it's available for config/environments/* - if we did this
    # instead in a config/initializers/* file, it wouldn't be executed in time.
    #
    Rails.application.config.uk_org_pond_hcms = OpenStruct.new( YAML.load_file( Rails.root.join( 'config' ).join( 'config.yml' ) ) )

  end
end
