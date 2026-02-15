Rails.application.config.to_prepare do
  Money.locale_backend   = :i18n
  Money.rounding_mode    = BigDecimal::ROUND_HALF_UP
  Money.default_currency = Hcms.config.currency
end
