# A PORO used for e.g. the "collection_select" helper, which provides a set of
# simple objects that return their internal and translated names.
#
class EventOnArchiveAction
  def self.types
    actions = Event::ON_ARCHIVE_ACTIONS.dup
    actions.delete(Event.on_archive_actions[:move]) if Page.blogs.count.zero?

    actions.map { |type| self.new(type) }
  end

  def initialize(type)
    @type = type
  end

  def internal_name
    @type
  end

  def human_name
    I18n.t("models.on_archive_action.#{@type}")
  end
end
