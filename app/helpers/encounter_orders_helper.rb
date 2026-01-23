module EncounterOrdersHelper
  def encordshelp_datetime(encounter)
    if encounter.starts_at.nil?
      'Open-ended'
    else
      apphelp_human_time(encounter.starts_at)
    end
  end
end
