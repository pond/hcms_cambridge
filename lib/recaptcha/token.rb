require 'json'
require 'recaptcha'
require 'base64'
require 'securerandom'
require 'openssl'

# module Base64
#   class << self
#     def urlsafe_encode64(bin)
#       [bin].pack("m0").tr("+/", "-_")
#     end
#   end
# end

module Recaptcha
  module Token

    # Ruby 1.8.7 lacks SecureRandom#uuid and Base64#urlsafe_encode64;
    # it also doesn't support packing by "m0", so inserts newlines into
    # encoded strings that we need to strip c.f. the Ruby 1.9.1 code
    # under the hood of #urlsafe_encode64.
    #
    def self.uuid
      ary = SecureRandom.random_bytes(16).unpack("NnnnnN")
      ary[2] = (ary[2] & 0x0fff) | 0x4000
      ary[3] = (ary[3] & 0x3fff) | 0x8000
      "%08x-%04x-%04x-%04x-%04x%08x" % ary
    end

    def self.urlsafe_encode64(bin)
      [bin].pack('m').tr("\n",'').tr('+/', '-_')
    end

    def self.secure_token
      private_key  =  Recaptcha.configuration.private_key
      raise RecaptchaError, "No private key specified." unless private_key

      stoken_json = {'session_id' => self.uuid, 'ts_ms' => (Time.now.to_f * 1000).to_i}.to_json
      cipher = OpenSSL::Cipher::AES128.new(:ECB)
      private_key_digest = Digest::SHA1.digest(private_key)[0...16]

      cipher.encrypt
      cipher.key = private_key_digest
      encrypted_stoken = cipher.update(stoken_json) << cipher.final
      self.urlsafe_encode64(encrypted_stoken).gsub(/\=+\Z/, '')
    end
  end
end