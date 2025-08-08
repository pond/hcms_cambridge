# A convenience object used by Admin::StatisticsController to collate data
# related to PageImpression records.
#
class Admin::Statistic
  include ActiveModel::API
  attr_accessor :source, :location, :count, :success
end
