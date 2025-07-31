module ApplicationHelper
  def apphelp_destroy_confirm(thing)
    message = 'Are you sure? This cannot be undone!'

    if thing.is_a?(Page) && thing.is_blog_type? && thing.articles.for_navigation.any?
      message = "Are you sure? The page's blog articles will be deleted too. This cannot be undone!"
    end

    message
  end

  def apphelp_human_time(datetime)
    time_zone    = Rails.application.config.uk_org_pond_hcms.time_zone || 'London'
    current_year = Time.now.in_time_zone(time_zone).year
    local_time   = datetime.in_time_zone(time_zone)
    formatter    = current_year == local_time.year ? :short_no_year : :short

    l(local_time, format: formatter)
  end

  # Writes out a label with required/optional hint if necessary and using I18n
  # that defaults to "label/<attrname>" as a model's human attribute name for
  # the label. This allows more descriptive label text, without e.g. validation
  # errors including those longer strings.
  #
  # Falls back to standard I18n human attribute names if no label-specific form
  # is found. Label text can be fully overridden with the "text" option.
  #
  # Options - :required/:optional => true to decorate label appropriately.
  #           :text => "..." to override the label text.
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

    form.label(attribute) { contents }
  end
end
