class Admin::StatisticsController < ApplicationController
  layout 'admin'

  before_action :authenticate_admin_user! # (via Devise)

  def index
    statistics  = {}
    @statistics = []
    batch_size  = 1000
    start_id    = PageImpression.first&.id
    end_id      = PageImpression.last&.id

    return if start_id.nil?

    # Yes, this is inefficient but it does work in parameterised pagination via
    # the batch size and ID ranges. We don't expect a huge number of discrete
    # page paths but the redirections might be an issue over time.
    #
    # Given ID range pagination we can't ask PG to sort the whole record set,
    # so again rely on there being overall not a huge statistic count and just
    # sort in Ruby once the stats are compiled.
    #
    loop do
      batch_query = PageImpression.where("id >= ? AND id < ?", start_id, start_id + batch_size)

      batch_query.each do | page_impression |
        statistics[page_impression.path] ||= generate_statistic_for(page_impression)
        statistics[page_impression.path].count += 1
      end

      start_id += batch_size
      break if start_id > end_id
    end

    @statistics = statistics.values.sort_by { |statistic| [statistic.source.controller, statistic.source.path] }
  end

  # The ID for a 'show' action is a PageImpression ID which has its +path+ used
  # as the basis for the statistics calculated herein.
  #
  def show
    page_impression = PageImpression.find(params[:id])
    page_impression = PageImpression.where(path: page_impression.path).last # Switch to most recent on same path

    @statistic = generate_statistic_for(page_impression, including_count: true)
    @referrers = PageImpression
      .where(path: page_impression.path)
      .where.not(referrer: [nil, ""])
      .group(:referrer)
      .reorder(Arel.sql('COUNT(*) DESC, referrer ASC'))
      .pluck(:referrer, Arel.sql('COUNT(*)'))
      .to_h
  end

  private

    def generate_statistic_for(page_impression, including_count: false)
      if page_impression.controller == 'pages' || page_impression.controller == 'articles'
        model_class = page_impression.controller.classify.safe_constantize

        if page_impression.action == 'show' && model_class.present? && page_impression.params.key?("id")
          instance = if model_class.respond_to?(:find_by_id_or_slug!)
            model_class.find_by_id_or_slug!(page_impression.params["id"]) rescue nil
          else
            model_class.find(page_impression.params["id"])
          end
          location = "#{model_class.model_name.human} - #{instance.title}" if instance.title.present?
        end
        location ||= "#{model_class&.model_name&.human || controller.capitalize} - #{mapped_action page_impression.action}"
      else
        location = "#{page_impression.controller&.capitalize} - #{mapped_action page_impression.action}"
      end

      Admin::Statistic.new(
        source:   page_impression,
        location: location,
        count:    including_count ? PageImpression.where(path: page_impression.path).count : 0,
        success:  (page_impression.status < 400),
      )
    end

    def mapped_action(action)
      if action.blank?
        'none'
      elsif action == 'index'
        'list'
      else
        action
      end
    end

end
