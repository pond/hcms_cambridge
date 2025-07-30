module ApplicationHelper
  def apphelp_destroy_confirm(thing)
    message = 'Are you sure? This cannot be undone!'

    if thing.is_a?(Page) && thing.is_blog_type? && thing.articles.any?
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

  # Options - :required/:optional => true to decorate label appropriately.
  #
  def apphelp_label(form, attribute, options = {})
    model     = form.object
    namespace = model.is_a?(ActiveRecord::Base) ? 'activerecord' : 'activemodel'
    i18n_key  = model.class.model_name.i18n_key
    text      = tag.span(model.class.human_attribute_name("labels/#{attribute}"), class: 'form_field_label')

    if options[:required]
      text = text.concat(tag.span(t('misc.required'), class: 'form_field_label_required'))
    end

    if options[:optional]
      text = text.concat(tag.span(t('misc.optional'), class: 'form_field_label_optional'))
    end

    form.label(attribute) { text }
  end
end
