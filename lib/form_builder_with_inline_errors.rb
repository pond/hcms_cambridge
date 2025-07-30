class FormBuilderWithInlineErrors < ActionView::Helpers::FormBuilder
  ERROR_CAPABLE_FIELDS = ActionView::Helpers::FormBuilder.field_helpers - [
    :label, :check_box, :radio_button, :fields_for, :fields, :hidden_field, :file_field
  ]

  ERROR_CAPABLE_FIELDS.each do | method_name |
    define_method(method_name) do | attribute, options = {} |
      super(attribute, options) + error_for(attribute)
    end
  end

  # ============================================================================
  # PRIVATE INSTANCE METHODS
  # ============================================================================
  #
  private

    def error_for(attribute)
      return unless object.errors[attribute].any?

      @template.content_tag(
        :div,
        object.class.human_attribute_name(attribute) + ' ' + object.errors.messages_for(attribute).to_sentence,
        class: 'field_error_messages'
      )
    end

end
