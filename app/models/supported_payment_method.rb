# A PORO used for e.g. the "collection_check_boxes" helper, which provides a set
# of simple objects that return their internal and translated names.
#
class SupportedPaymentMethod
  def self.methods
    EncounterOrder::SUPPORTED_PAYMENT_METHODS.map { |method| self.new(method) }
  end

  def initialize(method)
    @method = method
  end

  def internal_name
    @method
  end

  def human_name
    I18n.t("models.supported_payment_method.#{@method}")
  end

  def is_other?
    self.internal_name == EncounterOrder::SUPPORTED_PAYMENT_METHOD_OTHER
  end
end
