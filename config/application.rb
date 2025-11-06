require_relative 'boot'

%w(
  active_record/railtie
  action_controller/railtie
  action_view/railtie
  action_mailer/railtie
  active_job/railtie
  rails/test_unit/railtie
).each do |railtie|
  require railtie
end

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Hcms
  def self.config
    @config ||= Rails.application.config_for(:hcms) # See "config/hcms.yml"
  end

  class Application < Rails::Application
    config.load_defaults 8.0

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    config.autoload_lib(ignore: %w(assets tasks))

    # Set time zone for things like "Time.current".
    #
    config.time_zone = Hcms.config.time_zone || 'London'

  end
end
