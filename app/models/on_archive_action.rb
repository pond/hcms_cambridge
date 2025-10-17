# A PORO used for e.g. the "collection_select" helper, which provides a set of
# simple objects that return their internal and translated names.
#
class OnArchiveAction
  def self.types
    actions = Event::ORDERED_ARCHIVING_ACTIONS.dup
    actions.delete(Event::ON_ARCHIVE_MOVE) if Page.blogs.count.zero?

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
