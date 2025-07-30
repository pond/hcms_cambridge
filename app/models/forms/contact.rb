module Forms
  class Contact < Base
    attr_accessor :message

    validates :message, presence: true

    def self.permitted_params
      super + [:message]
    end
  end
end
