# HCMS uses the Redactor Rails gem for integration, which in
# turn uses the CarrierWave gem for file uploads. This stores
# to filesystems, not a database. On Heroku, things like a
# redeploy rebuild the container the application runs in, so
# any uploads - assuming they were even possible in the first
# place, as the filesystem might be configured read-only -
# are destroyed.
#
# Implement a nasty workaround which is generally OK, provided
# you don't get a validation error when submitting a new page,
# or edits to a page, *after* you've used Redactor to upload
# stuff into the editor area.
#
# https://github.com/carrierwaveuploader/carrierwave/wiki/How-to%3A-Make-Carrierwave-work-on-Heroku
# https://github.com/carrierwaveuploader/carrierwave#making-uploads-work-across-form-redisplays

def on_heroku?
  ENV.any? {|x,_| x=~ /^HEROKU/ }
end

if on_heroku?
  CarrierWave.configure do | config |
    config.cache_dir = "#{ Rails.root }/tmp/uploads"
  end
end
