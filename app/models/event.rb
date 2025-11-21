class Event < Editable
  include AASM

  mount_uploader :event_hero_image, EventHeroImageUploader

  belongs_to :page
  has_many :orders
  has_many :confirmed_orders, -> { self.confirmed }, class_name: 'Order' # (for eager-loading use only)
  has_one  :stripe_price, required: false, dependent: :destroy

  after_initialize(unless: :persisted?) do
    tz_now = Time.current

    self.starts_at = tz_now.beginning_of_day +  9.hours
    self.ends_at   = tz_now.beginning_of_day + 17.hours
    self.currency  = Hcms.config.currency
  end

  after_commit :stripe_make_inactive, on: :destroy

  # ============================================================================
  # Enumerations (see also any AASM state machine definition(s) later)
  # ============================================================================

  # NB: This is backed by a PostgreSQL enum, so changes require corresponding
  # migrations. Enum originally created by "20251010032150_add_events.rb".
  #
  # Using 'enum' will cause Rails to generate a bunch of accessors which use
  # "enum_state_" as a prefix, to avoid collision with an AASM state machine
  # defined later, which uses "state_" as a prefix and should always be used
  # in favour of the enum-defined methods to cause state changes and so-on.
  #
  enum(
    :state,
    {
      presales:           'presales',
      reserver_purchases: 'reserver_purchases',
      public_purchases:   'public_purchases',
      archived:           'archived',
      cancelled:          'cancelled',
    },
    prefix:  'enum_state',
    default: :presales,
  )

  STATES = self.states.keys

  # NB: This is backed by a PostgreSQL enum, so changes require corresponding
  # migrations. Enum originally created by "20251010032150_add_events.rb".
  #
  enum(
    :on_archive_action,
    {
      keep: 'keep', # Ends up in 'past events' subsection on event page
      hide: 'hide', # Set as "hidden"; links work, but not shown in navigation
      move: 'move', # Convert and move to blog indicated by archive params
    },
    prefix:  true,
    default: :keep,
  )

  ON_ARCHIVE_ACTIONS = self.on_archive_actions.keys

  # ============================================================================
  # Scopes
  # ============================================================================

  STATE_LIST_SQL = <<~SQL
    CASE state
      WHEN ? THEN 1
      WHEN ? THEN 1
      WHEN ? THEN 1
      WHEN ? THEN 2
      WHEN ? THEN 3
      ELSE 100
    END ASC,
    starts_at ASC
  SQL

  default_scope -> {
    order(
      Arel.sql(
        self.sanitize_sql_array([
          STATE_LIST_SQL,
          self.states[:presales          ],
          self.states[:reserver_purchases],
          self.states[:public_purchases  ],
          self.states[:archived          ],
          self.states[:cancelled         ],
        ])
      )
    )
  }

  default_scope -> { order(starts_at: :asc) }

  scope :not_hidden, -> { where(hidden: false) }

  scope :for_navigation, -> {
      where(id: Revision.published.where(revisable_type: 'Event').select(:revisable_id))
      .not_hidden
      .not_enum_state_cancelled
  }

  # ============================================================================
  # Validations
  # ============================================================================

  validates_presence_of %i{
    summary
    body
    currency
    starts_at
    ends_at
    state
    on_archive_action
  }

  # Note that the state and on-archive enums are validated automatically.

  validates :event_hero_image, presence: true, on: :create

  with_options unless: [:state_archived?, :state_cancelled?] do
    validates :starts_at, comparison: { greater_than: -> { Time.current }, message: 'must be in the future' }
    validates :ends_at,   comparison: { greater_than: -> { Time.current }, message: 'must be in the future' }

    validate do | event |
      if ((event.starts_at >= event.ends_at) rescue false)
        event.errors.add(:ends_at, 'must be after the start time')
      end
    end
  end

  # ============================================================================
  # Overrides of Editable base class
  # ============================================================================

  def is_event?
    true
  end

  def for_navigation?
    self.published_revision.present? && self.hidden == false
  end

  def collapse_metadata_in_form?
    ! self.new_record? && self.valid?
  end

  # ============================================================================
  # Miscellaneous
  # ============================================================================

  # Is the event free of charge?
  #
  def free_of_charge?
    self.price_per_seat.zero?
  end

  # Does the event have uncounted (effectively, unrestricted) seating?
  #
  def unrestricted_seating?
    self.number_of_seats.zero?
  end

  # An at-the-instant estimate; returns +nil+ if seat count is unlimited. Never
  # returns less than zero otherwise.
  #
  def provisional_seats_remaining
    if self.unrestricted_seating?
      return nil
    else
      @provisional_seats_remaining ||= begin
        orders = self.orders.inflight
        [0, self.number_of_seats - orders.sum(:number_of_seats)].max()
      end
    end
  end

  # An at-the-instant count based on reserved or paid orders only and will allow
  # a negative return value if an event ends up oversubscribed (e.g. because the
  # event was edited after orders had been placed). Returns +nil+ if seat count
  # is unlimited.
  #
  def confirmed_seats_remaining
    if self.unrestricted_seating?
      return nil
    else
      @confirmed_seats_remaining ||= self.number_of_seats - self.confirmed_seats_taken
    end
  end

  # Opposite of #confirmed_seats_remaining, giving the number of seats taken.
  #
  def confirmed_seats_taken
    if self.unrestricted_seating?
      return nil
    else
      @confirmed_seats_taken ||= self.confirmed_orders.sum(&:number_of_seats)
    end
  end

  # This is mostly here for local development and test purposes, where file
  # storage is in use - otherwise the event hero URL from S3 is used.
  #
  def product_image_url
    product_image_url = if self.event_hero_image.class.storage == CarrierWave::Storage::File
      'https://upload.wikimedia.org/wikipedia/commons/1/15/Hieronymus_Bosch_-_Allegory_of_Gluttony_and_Lust_-_WGA02558.jpg'
    else
      self.event_hero_image.url
    end
  end

  def get_or_create_stripe_price(with_event_url:)
    return self.stripe_price || begin
      product_result = Stripe::Product.create(
        name:        self.title,
        description: ApplicationController.helpers.evtshelp_datetime(self),
        images:      [self.product_image_url],
        shippable:   false,
        unit_label:  'seat',
        url:         with_event_url,
      )

      price_result = Stripe::Price.create(
        currency:     self.currency,
        unit_amount:  self.price_per_seat,
        product:      product_result.id
      )

      StripePrice.create!(
        event:           self,
        stripe_price_id: price_result.id,
      )
    end
  end

  # ============================================================================
  # Utility functions
  # ============================================================================

  def human_state
    EventState.new(self.state).human_name
  end

  # ============================================================================
  # AASM STATE MACHINE namespace 'state': Main definition
  # ============================================================================

  aasm(:state, namespace: 'state') do
    state :presales, initial: true
    state :reserver_purchases
    state :public_purchases
    state :archived
    state :cancelled

    event :start_reserver_purchases, after_commit: :notify_reservers do
      transitions(
        from:  :presales,
        to:    :reserver_purchases,
        guard: [:has_reservers?, :has_not_started?]
      )
    end

    event :start_public_purchases, after_commit: :cancel_reservations_and_notify_reservers do
      transitions(
        from:  [:presales, :reserver_purchases],
        to:    :public_purchases,
        guard: :has_not_ended?
      )
    end

    event :archive, after_commit: [:perform_on_archive_action, :stripe_make_inactive] do
      transitions(
        from:  [:presales, :reserver_purchases, :public_purchases],
        to:    :archived,
        guard: :has_ended?
      )
    end

    event :cancel, after_commit: [:update_orders_for_cancellation, :stripe_make_inactive] do
      transitions(
        from: [:presales, :reserver_purchases, :public_purchases],
        to:   :cancelled
      )
    end
  end

  # The 'aasm(:state)' method on 'self' does not appear to take account of
  # guards, only transition conditions. The method here only returns events
  # the instance can *actually* use - at least, at the instant of calling.
  #
  def valid_events
    Event.aasm(:state).events.filter do |event|
      self.send("may_#{event.name}_state?")
    end
  end

  # ============================================================================
  # AASM STATE MACHINE namespace 'state': Guards
  # ============================================================================

  def has_reservers?
    self.orders.enum_state_reserved.any?
  end

  def has_started?
    self.starts_at <= Time.current
  end

  def has_not_started?
    ! self.has_started?
  end

  def has_ended?
    self.persisted? && self.ends_at <= Time.current
  end

  def has_not_ended?
    ! self.has_ended?
  end

  # ============================================================================
  # PRIVATE INSTANCE METHODS
  # ============================================================================
  #
  private

    # Called before-destroy. If there are "relevant state" orders associated,
    # refuse to exit. "Relevant" means - not in "new" (initial) or "cancelled"
    # states. If there any reservations or paid items

    # ==========================================================================
    # AASM STATE MACHINE namespace 'state': After-commit handlers
    # ==========================================================================

    # Notify reservers that they can now make purchases via their magic link and
    # that once public sales start, it becomes a free-for-all.
    #
    def notify_reservers
      self.orders.enum_state_reserved.where.not(amount_owed: 0).each do |order|
        OrderMailer.event_state_reserver_purchases_email(order).deliver_later()
      end
    end

    # Notify reservers that sales are now open to the public, so they need to
    # confirm their booking via payment ASAP or risk losing the seat.
    #
    # If there seems to be an error with notification, the order state change is
    # rolled back and an alert is sent out via Sentry.
    #
    def cancel_reservations_and_notify_reservers
      self.orders.enum_state_reserved.each do |order|
        ActiveRecord::Base.transaction do
          if order.amount_owed.zero?
            order.update!(state: Order.states[:paid])
          else
            order.update!(state: Order.states[:new])
            OrderMailer.event_state_public_purchases_email(order).deliver()
          end
        rescue => e
          Sentry.capture_exception(e)
          raise ActiveRecord::Rollback
        end
      end
    end

    # The event has been archived; perform the "on archive" action.
    #
    def perform_on_archive_action

      # IMPORTANT: Remember to avoid triggering more callbacks here; we're in an
      # after-commit hook via AASM, so caution is required.
      #
      case self.on_archive_action
        when Event.on_archive_actions[:hide]
          self.update_column(:hidden, true)

        when Event.on_archive_actions[:move]
          blog     = Page.blogs.find_by_id(self.on_archive_params&.dig("blog_id"))
          revision = self.current_revision || self.revisions.order(created_at: :desc).first

          if blog.present? && revision.present?
            ActiveRecord::Base.transaction do
              self.update_column(:hidden, true)

              article = Article.new(
                page_id:            blog.id,
                created_at:         self.starts_at,
                updated_at:         self.starts_at,
                article_hero_image: self.event_hero_image,
                raw_editor:         self.raw_editor,
              )

              article.generate_unique_slug(starting_with: self.slug)

              revision = article.revisions.build(
                title:            revision.title,
                navigation_title: revision.navigation_title,
                summary:          revision.summary,
                body:             revision.body,
                published:        true,
                current:          true
              )

              article.save!
            end
          end

        else
          # Do nothing - state is either "keep" or not yet implemented.
      end
    end

    # The event has been cancelled. Run order updates for appropriate states and
    # let the order model take care of notification e-mails.
    #
    def update_orders_for_cancellation

      # People who've paid get refunded.
      #
      self.orders.enum_state_paid.each do |order|
        ActiveRecord::Base.transaction do
          order.refund_state!
        rescue => e
          Sentry.capture_exception(e)
          raise ActiveRecord::Rollback
        end
      end

      # People with reservations have those reservations cancelled.
      #
      self.orders.enum_state_reserved.each do |order|
        ActiveRecord::Base.transaction do
          order.cancel_state!
        rescue => e
          Sentry.capture_exception(e)
          raise ActiveRecord::Rollback
        end
      end

      # New orders get set to a cancelled state too, but without a notification
      # e-mail since the order was never confirmed.
      #
      self.orders.enum_state_new.each do |order|
        begin
          order.update!(state: Order.states[:cancelled])
        rescue => e
          Sentry.capture_exception(e)
        end
      end
    end

    # An event is archived or cancelled; update Stripe accordingly. This handler
    # is also called after-commit-on-destroy.
    #
    def stripe_make_inactive
      if self.stripe_price
        price   = Stripe::Price.retrieve(self.stripe_price.stripe_price_id)
        product = Stripe::Product.retrieve(price.product)

        Stripe::Product.update(product.id, {active: false})
        Stripe::Price.update(price.id, {active: false})
      end
    end

end
