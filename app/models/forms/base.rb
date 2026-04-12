module Forms
  class Base
    include ActiveModel::API

    # The "pagelike" attribute holds a Page or, as far as subclassed forms go,
    # sufficiently Page-like object such as an Encounter.
    #
    attr_accessor :pagelike, :name, :email, :phone, :menu_selection

    validates :pagelike, presence: true
    validates :name,     presence: true
    validates :email,    presence: true
    validates :email,    allow_blank: true, format: URI::MailTo::EMAIL_REGEXP
    validates :phone,    phone: { allow_blank: true } # (via Phonelib gem)

    def self.permitted_params
      [:name, :email, :phone, :menu_selection]
    end

  end
end
