module Forms
  class Booking < Base
    attr_accessor :time, :date, :notes

    validates(
      :notes,
      presence: true,
      if:       -> (form_model) {
        form_model.pagelike.is_a?(Encounter)
      }
    )

    def self.permitted_params
      super + [:time, :date, :notes]
    end
  end
end
