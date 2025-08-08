module Forms
  class Base
    include ActiveModel::API

    attr_accessor :page, :name, :email, :phone, :menu_selection

    validates :page,  presence: true
    validates :name,  presence: true
    validates :email, presence: true
    validates :email, allow_blank: true, format: URI::MailTo::EMAIL_REGEXP
    validates :phone, phone: { allow_blank: true } # (via Phonelib gem)

    def self.permitted_params
      [:name, :email, :phone, :menu_selection]
    end

  end
end
