# https://github.com/ambethia/recaptcha#alternative-api-key-setup
#
Recaptcha.configure do | config |
  site_key   = ENV[ 'RECAPTCHA_SITE_KEY'   ] || ENV[ 'RECAPTCHA_PUBLIC_KEY'  ]
  secret_key = ENV[ 'RECAPTCHA_SECRET_KEY' ] || ENV[ 'RECAPTCHA_PRIVATE_KEY' ]

  if site_key && secret_key
    config.site_key   = site_key
    config.secret_key = secret_key
  else
    key_id     = ENV[ 'RECAPTCHA_KEY_ID'            ]
    api_key    = ENV[ 'RECAPTCHA_GCLOUD_API_KEY'    ]
    project_id = ENV[ 'RECAPTCHA_GCLOUD_PROJECT_ID' ]

    if key_id && api_key && project_id
      config.enterprise            = true
      config.enterprise_api_key    = api_key
      config.enterprise_project_id = project_id
      config.site_key              = key_id # (sic.)
    end
  end
end
