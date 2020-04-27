require_relative 'boot'

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Hcms
  class Application < Rails::Application
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    config.active_record.raise_in_transactional_callbacks = true

    config.autoload_paths << Rails.root.join('lib', 'recaptcha')

    Rails.application.config.uk_org_pond_hcms = OpenStruct.new( YAML.load_file( Rails.root.join( 'config' ).join( 'config.yml' ) ) )
  end
end
