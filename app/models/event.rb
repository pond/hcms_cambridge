class Event < Editable
  mount_uploader :event_hero_image, EventHeroImageUploader

  belongs_to :page

  default_scope -> { order(archived: :asc, starts_at: :asc) }

  scope :for_navigation, -> {
    where(id: Revision.published.where(revisable_type: 'Event').select(:revisable_id))
  }



  # UPON ARCHIVING:
  #
  # - hide the page from navigation
  # - keep the page as a historical item (make sure the view shows this clearly)
  # - move the event into a blog as an article



  validates_presence_of %i{
    event_hero_image
    summary
    body

    starts_at
    ends_at
    number_of_seats
    price_per_seat
    currency
  }

  def is_event?
    true
  end

  def for_navigation?
    self.published_revision.present?
  end

  # A newer event - next greater created_at. Assumes no two identical times.
  #
  def next
    @next ||= self.class
      .reorder(created_at: :asc)
      .where(page_id: self.page_id)
      .where('created_at > ?', self.created_at)
      .first
  end

  # An older event - next lower created_at. Assumes no two identical times.
  #
  def prev
    @prev ||= self.class
      .reorder(created_at: :desc)
      .where(page_id: self.page_id)
      .where('created_at < ?', self.created_at)
      .first
  end
end
