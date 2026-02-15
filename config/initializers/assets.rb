# Be sure to restart your server when you modify this file.

# Version of your assets, change this if you want to expire all your assets.
Rails.application.config.assets.version = '2.4'

# Add additional assets to the asset load path
# Rails.application.config.assets.paths << Emoji.images_path

# Precompile additional assets.
# application.js, application.css, and all non-JS/CSS in app/assets folder are already added.
# Rails.application.config.assets.precompile += %w( search.js )

# The logo is included since that SVG file is now directly referenced in the
# event ordering system for branding in (for example) Stripe. If it were ever
# not included in views also, it wouldn't be compiled and purchases would fail.
#
Rails.application.config.assets.precompile += %w( pages.css admin.css minimal.js admin.js logo.svg )
