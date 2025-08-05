# A PORO used for e.g. the "collection_select" helper, which provides a set of
# simple objects that return their internal and translated names.
#
class PageType
  def self.types
    Page::ORDERED_PAGE_TYPES.map { |type| self.new(type) }
  end

  def initialize(type)
    @type = type
  end

  def internal_name
    @type
  end

  def human_name
    I18n.t("models.page_type.#{@type}")
  end
end
