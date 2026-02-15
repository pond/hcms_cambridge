class Encounter < Editable
  include AASM

  mount_uploader :encounter_hero_image, EncounterHeroImageUploader

  has_many :encounter_orders
  has_many :confirmed_emncounter_orders, -> { self.confirmed }, class_name: 'EncounterOrder' # (for eager-loading use only)
  has_one  :stripe_price, as: :priceable, required: false, dependent: :destroy

  after_initialize(unless: :persisted?) do
    self.currency  = Hcms.config.currency
  end

  after_commit :stripe_make_inactive, on: :destroy

  # ============================================================================
  # Scopes
  # ============================================================================

  default_scope -> { order(created_at: :asc) }

  scope :for_navigation, -> { none() }

  # ============================================================================
  # Validations
  # ============================================================================

  validates_presence_of %i{
    summary
    body
    currency
  }

  validates :encounter_hero_image, presence: true, on: :create

  validate :name_physical do
    if self.has_physical_aspect? && self.name_physical.blank?
      self.errors.add(:name_physical, :blank)
    end
  end

  # ============================================================================
  # Internal utility class used in very limited cases for plain text body data
  # ============================================================================

  class EncounterToPlain
    include ActionView::Helpers::SanitizeHelper

    attr_reader :encounter

    def initialize(encounter)
      @encounter = encounter
    end

    def plain_body_text
      strip_tags(self.encounter.body)
    end
  end

  # ============================================================================
  # Overrides of Editable base class
  # ============================================================================

  def is_encounter?
    true
  end

  def collapse_metadata_in_form?
    ! self.new_record? && self.valid?
  end

  # ============================================================================
  # Miscellaneous
  # ============================================================================

  # Is the encounter free of charge?
  #
  def free_of_charge?
    self.price_per_seat.zero?
  end

  # Does the encounter have a physical associated aspect?
  #
  def has_physical_aspect?
    self.price_physical.present?
  end

  # Does the encounter have a free physical associated aspect?
  #
  def physical_aspect_free_of_charge?
    self.price_physical.zero?
  end

  # This is mostly here for local development and test purposes, where file
  # storage is in use - otherwise the encounter hero URL from S3 is used.
  #
  def product_image_url
    product_image_url = if self.encounter_hero_image.class.storage == CarrierWave::Storage::File
      'https://upload.wikimedia.org/wikipedia/commons/1/15/Hieronymus_Bosch_-_Allegory_of_Gluttony_and_Lust_-_WGA02558.jpg'
    else
      self.encounter_hero_image.url
    end
  end

  # Does the encounter's currency symbol or code appear inside the summary or
  # description text?
  #
  def might_include_price_details?
    return false if self.currency.blank?

    symbol = Money.new(self.currency).symbol

    # Bail early on the less expensive check; plain text short summary.
    #
    return true if self.summary.include?(symbol) || self.summary.include?(self.currency)

    if self.body.include?(symbol) || self.body.include?(self.currency)
      converter  = ::Encounter::EncounterToPlain.new(self)
      plain_text = converter.plain_body_text

      return plain_text.include?(symbol) || plain_text.include?(self.currency)
    else
      return false
    end
  end

  # Sync with Stripe, creating a Stripe Price for this Encounter if need be.
  #
  def get_or_create_stripe_price(with_encounter_url:)
    return self.stripe_price || begin
      product_result = Stripe::Product.create(
        name:        self.title,
        images:      [self.product_image_url],
        shippable:   false,
        unit_label:  'seat',
        url:         with_encounter_url,
      )

      price_result = Stripe::Price.create(
        currency:     self.currency,
        unit_amount:  self.price_per_seat,
        product:      product_result.id
      )

      StripePrice.create!(
        priceable:       self,
        stripe_price_id: price_result.id,
      )
    end
  end

  # ============================================================================
  # PRIVATE INSTANCE METHODS
  # ============================================================================
  #
  private

    # Called after-commit-on-destroy; deactivates a Stripe product/price pair,
    # if present.
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
