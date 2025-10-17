# A PORO used for e.g. the "collection_select" helper, which provides a set of
# simple objects that return their internal and translated names.
#
class EventState
  def self.types
    Event::EVENT_STATES.map { |type| self.new(type) }
  end

  def initialize(type)
    @type = type
  end

  def internal_name
    @type
  end

  def human_name
    I18n.t("models.event_state.#{@type}")
  end
end
