module Forms
  class Booking < Base
    attr_accessor :time, :date, :notes, :selection

    def self.permitted_params
      super + [:time, :date, :notes, :selection]
    end
  end
end
