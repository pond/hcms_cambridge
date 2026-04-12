module ApplicationHelper
  def apphelp_destroy_confirm(thing)
    message = 'Are you sure? This cannot be undone!'

    if thing.is_a?(Page)
      if thing.is_blog_type? && thing.articles.for_navigation.any?
        message = "Are you sure? The page's blog articles will be deleted too. This cannot be undone!"
      elsif thing.is_events_type? && thing.events.for_navigation.any?
        message = "Are you sure? This page's listed events will be deleted too. This cannot be undone!"
      end
    end

    message
  end

  def apphelp_human_time(datetime, time_only: false, date_only: false, invoice: false)
    TimeZoneHelp.in_configured_time_zone(datetime, time_only:, date_only:, invoice:)
  end

  # Render a boolean-like thing as 'yes/no' text in a span that can include a
  # given yes/no HTML class used to modify the presentation style.
  #
  def apphelp_boolean(boolean, yes_class: 'boolean_yes', no_class: 'boolean_no')
    if boolean
      tag.span(t('misc.yes'), class: yes_class)
    else
      tag.span(t('misc.no'), class: no_class)
    end
  end

  # Writes out a label with required/optional hint if necessary and using I18n
  # that defaults to "label/<attrname>" as a model's human attribute name for
  # the label. This allows more descriptive label text, without e.g. validation
  # errors including those longer strings.
  #
  # Falls back to standard I18n human attribute names if no label-specific form
  # is found. Label text can be fully overridden with the "text" option. Hint
  # text can be appended after everything else, via the "hint" option.
  #
  # Options:
  #
  # * required:/optional: true to decorate label appropriately.
  # * text: String to override the label text.
  # * hint: String of hint text to append (after required/optional, if used).
  #
  def apphelp_label(form, attribute, options = {})
    model     = form.object
    namespace = model.is_a?(ActiveRecord::Base) ? 'activerecord' : 'activemodel'
    i18n_key  = model.class.model_name.i18n_key
    text      = options[:text].presence || model.class.human_attribute_name("labels/#{attribute}", default: model.class.human_attribute_name(attribute))
    contents  = tag.span(text, class: 'form_field_label')

    if options[:required]
      contents.concat(tag.span(t('misc.required'), class: 'form_field_label_required'))
    end

    if options[:optional]
      contents.concat(tag.span(t('misc.optional'), class: 'form_field_label_optional'))
    end

    if options[:hint].present?
      contents.concat(tag.span(options[:hint], class: 'form_field_label_hint'))
    end

    form.label(attribute) { contents }
  end

  # Return an amount of money formatted for a given (default - globally
  # configured) configured currency, for a value expressed in 'cents', i.e.
  # fractional units) with an optional support for 'free of charge' via the
  # given boolean, or 'price on application' (supersedes 'free of charge').
  #
  # Returns an en-dash HTML entity if there's no currency configured or given
  # (specify via an ISO 3-letter code such as GBP or NZD).
  #
  def apphelp_money(amount_in_cents, currency: Hcms.config.currency, free_of_charge: false, poa: false)
    if currency.blank?
      '&ndash;'.html_safe()
    elsif poa
      Encounter.human_attribute_name(:price_on_application)
    elsif free_of_charge
      'Free'
    else
      parsed_amount = Money.from_cents(amount_in_cents, currency)
      parsed_amount.format()
    end
  end
end
