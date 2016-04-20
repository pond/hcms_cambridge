require "uri"
require "json"

module Recaptcha
  module Verify
    # Your private API can be specified in the +options+ hash or preferably
    # using the Configuration.
    def verify_recaptcha(options = {})
      if !options.is_a? Hash
        options = {:model => options}
      end

      env = options[:env] || ENV['RAILS_ENV']
      return true if Recaptcha.configuration.skip_verify_env.include? env
      model = options[:model]
      attribute = options[:attribute] || :base
      private_key = options[:private_key] || Recaptcha.configuration.private_key
      raise RecaptchaError, "No private key specified." unless private_key

      begin
        recaptcha = nil
        if(Recaptcha.configuration.proxy)
          proxy_server = URI.parse(Recaptcha.configuration.proxy)
          http = Net::HTTP::Proxy(proxy_server.host, proxy_server.port)
          raise "Proxy code compatible with HTTPS and Ruby 1.8.7 hasn't been written yet"
        end

        url = URI.parse(Recaptcha.configuration.verify_url)
        req = Net::HTTP::Post.new(url.request_uri)
        req.set_form_data({
          "secret"    => private_key,
          "remoteip"  => request.remote_ip,
          "response"  => params['g-recaptcha-response']
        })
        http = Net::HTTP.new(url.host, url.port)
        http.use_ssl = (url.scheme == "https")
        Timeout::timeout(options[:timeout] || 3) do
          recaptcha = http.request(req)
        end

        json = JSON.parse(recaptcha.body) rescue {"success" => false}

        answer, error = recaptcha.body.split.map { |s| s.chomp }
        if json['success'] == true
          return true
        else
          if model
            message = "Word verification response is incorrect, please try again."
            message = I18n.translate(:'recaptcha.errors.verification_failed', {:default => message}) if defined?(I18n)
            model.errors.add attribute, options[:message] || message
          end
          return false
        end
      rescue Timeout::Error
        raise "reCaptcha system is not available (timeout)"
      end
    end # verify_recaptcha
  end # Verify
end # Recaptcha
