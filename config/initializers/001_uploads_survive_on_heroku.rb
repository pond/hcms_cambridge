# https://github.com/carrierwaveuploader/carrierwave/wiki/How-to%3A-Make-Carrierwave-work-on-Heroku
# https://github.com/carrierwaveuploader/carrierwave#making-uploads-work-across-form-redisplays

def use_s3?
  ENV.any? {|x,_| x=~ /^AWS_ACCESS_KEY_ID/ }
end

if use_s3?
  CarrierWave.configure do |config|
    config.fog_credentials = {
      :provider               => 'AWS',
      :aws_access_key_id      => ENV['AWS_ACCESS_KEY_ID'],
      :aws_secret_access_key  => ENV['AWS_SECRET_ACCESS_KEY'],
      :region                 => ENV['AWS_S3_REGION']
    }
    config.fog_directory  = ENV['AWS_S3_BUCKET_NAME']
    config.fog_provider   = 'fog/aws'
    config.storage        = :fog
  end
end
