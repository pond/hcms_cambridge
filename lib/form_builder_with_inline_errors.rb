class FormBuilderWithInlineErrors < ActionView::Helpers::FormBuilder
  ERROR_CAPABLE_FIELDS = ActionView::Helpers::FormBuilder.field_helpers - [
    :label, :check_box, :radio_button, :fields_for, :fields, :hidden_field
  ]

  ERROR_CAPABLE_FIELDS.each do | method_name |
    define_method(method_name) do | attribute, options = {} |
      super(attribute, options) + self.error_markup_for(attribute)
    end
  end

  # ============================================================================
  # PRIVATE INSTANCE METHODS
  # ============================================================================
  #
#  private

  # Class method which can be used externally for awkward fields where automatic
  # annotation isn't available; generates consistent error message markup for a
  # given ActiveRecord record instance and attribute. Returns an empty string if
  # there is no associated error for the given attribute.
  #
    def error_markup_for(attribute)
      return unless self.object.errors[attribute].any?

      @template.content_tag(
        :div,
        self.object.class.human_attribute_name(attribute) + ' ' + self.object.errors.messages_for(attribute).to_sentence,
        class: 'field_error_messages'
      )
    end

end
