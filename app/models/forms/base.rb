module Forms
  class Base
    include ActiveModel::API

    attr_accessor :page, :name, :email, :phone, :menu_selection

    validates :page,  presence: true
    validates :name,  presence: true
    validates :email, presence: true
    validates :email, allow_blank: true, format: URI::MailTo::EMAIL_REGEXP
    validate  :validate_phone_number

    def self.permitted_params
      [:name, :email, :phone, :menu_selection]
    end

    # ==========================================================================
    # PRIVATE INSTANCE METHODS
    # ==========================================================================
    #
    private

      def validate_phone_number
        return if phone.blank?

        country_dial_code = Rails.application.config.uk_org_pond_hcms.country_dial_code || '64'
        normalized        = Phony.normalize(phone) rescue ''

        unless Phony.plausible?(normalized)
          normalized = country_dial_code + normalized
        end

        unless Phony.plausible?(normalized)
          errors.add(:phone, :format)
        end
      end

  end
end
