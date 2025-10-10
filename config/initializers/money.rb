Rails.application.config.to_prepare do
  Money.locale_backend = :i18n
end
