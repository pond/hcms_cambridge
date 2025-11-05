# HCMS

This is a _very simple_ content management system designed for small web sites. Pages are edited with Imperavi's [Redactor](https://imperavi.com/redactor/) editor or optionally (per page) just with raw HTML. File uploads are supported via the [CarrierWave](https://github.com/carrierwaveuploader/carrierwave) gem, supporting storage locations such as local filesystem or Amazon S3.

HCMS source code is managed by Git and hosted by GitHub; site styling is done by modifying the Rails static CSS, static images and layout templates in the CMS using a branch off `master` or a fork.

## Setup
### Standard approach

Install gems, set up the database and create a starting point home page.

```shell
bundle install
bundle exec rake db:create db:schema:load db:seed
```

Now visit the site (e.g. visit `http://localhost:3000`) to see the default home page, proving that the application is working normally. **Add `/hcms` to the URL to be given a login page** (this 'magic link' is something you must 'just know' to get to administrative functions) then follow the "sign up" link to create an admin account. Presently, only one account is supported.

### Alternative clean-start approach

If you prefer to run all migrations sequentially instead of loading by schema, opting to set up data from clean:

```shell
bundle install
bundle exec rake db:create db:migrate
```

...then to define an starter Home page, if you want one, using Rake rather than loading all seed data:

```shell
bundle exec rake setup:home
```

## Route overview
### Admin

All routes at `/hcms/...` are for editing pages and so-on.

### Public

All other routes from `/` are for public page views.

## Configuration
### Heroku configuration
#### Rails

HCMS can be deployed to Heroku by-the-book:

* https://devcenter.heroku.com/articles/getting-started-with-rails8

The free Heroku database offering is generally OK as HCMS is such a simple, stripped down, small scale site engine that it's hard to imagine getting anywhere near the (at time of writing) 10,000 row limit in the free plan. Even so, extra backup/resilience/uptime/rollback facilities in paid plans might be desirable.

#### Papertrail logging

Papertrail is a free extension and useful for log insights:

* https://devcenter.heroku.com/articles/papertrail

#### Mailgun for e-mail

E-mails are sent using Mailgun. Heroku's out-of-box free integration works well, or you can use a MailGun account you've signed up separately. Specify your Mailgun API key and domain (found in the MailGun admin settings) via environment variables `MAILGUN_API_KEY` and `MAILGUN_DOMAIN`; for example, to test in the sandbox it'd look something like this:

```shell
heroku config:set MAILGUN_API_KEY="xxxxx-yyy-zzz"          --app your-appname-1234
heroku config:set MAILGUN_DOMAIN="sandbox1234.mailgun.org" --app your-appname-1234
```

#### Amazon S3 for file storage

You can use Amazon S3 storage instead of the web server's local filesystem for uploaded files and documents - e.g. because you're on Heroku, where the filesystem is transient rather than persistent. To do so, you must set some environment variables to tell the CarrierWave upload handler what to do.

First, you'll need to set up a bucket using the Amazon S3 web interface. Ideally set up a brand new IAM user for the access ID and key. The interface for this is rather complex, but at least assigning an out-of-the-box S3 'grant all' policy should be sufficient for that user. In any case, through the Amazon console you'll know your access ID and secret keys, you'll have chosen a hosting region for your S3 bucket and you'll have given it a name.

Next set variable `AWS_ACCESS_KEY_ID` to switch CarrierWave over to Amazon S3 storage. `AWS_SECRET_ACCESS_KEY` gives CarrierWave the S3 secret key, `AWS_S3_REGION` gives it the region (e.g. `eu-west-1`) and `AWS_S3_BUCKET_NAME` tells it the name of the bucket you created. On Heroku, you set these with the `heroku` command. See this page for help:

  https://devcenter.heroku.com/articles/s3

In brief:

```shell
heroku config:set AWS_ACCESS_KEY_ID="xxx" AWS_SECRET_ACCESS_KEY="yyy" --app your-appname-1234
heroku config:set AWS_S3_REGION="region"                              --app your-appname-1234 # e.g. 'eu-west-1'
heroku config:set AWS_S3_BUCKET_NAME="s3-bucket-name"                 --app your-appname-1234
```

### Other configuration

The configuration described above may be _required_ for Heroku but are otherwise optional on other deployment platforms; meanwhile, various other integrations can be used for any deployment platform you choose.

#### Stripe payments

HCMS supports a booking enquiries suitable for on-demand services where a customer enquires about something they want and a time/date is negotiated off-site (e.g. by e-mail or phone), along with prices and payments. There's also a general purpose contact form option. Other than filling in an e-mail address on which to receive those sorts of enquiries, there's no other setup needed.

 Additionally, there is a more formal event system. You create a page that acts a bit like a blog, except instead of writing blog articles, you write pages that describe scheduled events with, typically, a fixed price and fixed number of seats (though free-of-charge / no-seat-count options are available). You _can_ opt to just accept ad hoc payments (e.g. bank transfer) if you wish, or take advantage of HCMS's Stripe integration if you're happy using Stripe as a processor - with the fees this involves, but also with the advantages in terms of Stripe invoice and receipt generation, multiple payment method support, international currency support and so-on.

 Stripe payments are enabled by simply specifying your _private_ API key (be that your live key, or a development sandbox key - those start with `sk_test_...`) in environment variable `STRIPE_API_KEY`, e.g.:

```shell
heroku config:set STRIPE_API_KEY="sk_test_..." --app your-appname-1234
```

With this done, Stripe payment support is activated. When a user chooses to pay for an event on-site, they'll be sent to the Stripe hosted checkout page (where appearance is configured via Stripe's settings UI). If they cancel, then the user is returned to HCMS with their order cancelled; else the order is marked as successful and the Stripe payment details are connected to it. You can then issue a refund, should you wish, directly from inside HCMS - this means the order state on HCMS's site is kept up to date and the user will receive a refund notifiation e-mail from HCMS as well as Stripe. The former is more "friendly" and relevant in tone and branding to your site and the event you offered.

#### GTM

A Google site tag snippet is included for your AD ID (`9xxyyyzzz` or some similar number) if you specify the GOOGLE_AD_ID variable.

```shell
heroku config:set GOOGLE_AD_ID="9xxyyyzzz" --app your-appname-1234
```

#### Sentry error monitoring

Error monitoring via [Sentry](https://sentry.io) is enabled if you define environment variable `SENTRY_DSN` to your Sentry DSN (see your Sentry admin dashboard to find this).

```shell
heroku config:set SENTRY_DSN="https://1234@4567.ingest.de.sentry.io/6789" --app your-appname-1234
```



## Development
### Mailcatcher

ActiveMailer is configured for use with [MailCatcher](https://github.com/sj26/mailcatcher). You should install this gem separately, as it has requirements on gems such as Rake or Thin which are mutually incompatible with the bundle used by HCMS.

```
gem install mailcatcher
mailcatcher
```

A daemon will listen at localhost port 1080 for a web UI showing received mail, with an SMTP server on localhost port 1025 - this is the thing that HCMS is configured to communicate with for local development.

If you want to sometimes use Mailgun's sandbox from localhost but otherwise use Mailcatcher and don't want to have to keep remembering the `MAILGUN_API_KEY` and `MAILGUN_DOMAIN` you're supposed to put on the CLI to run the Rails server, then include `MAILCATCHER_OVERRIDES_MAILGUN=true` in the list. For example:

```shell
MAILGUN_API_KEY="xxxxx-yyy-zzz" \
MAILGUN_DOMAIN="sandbox1234.mailgun.org" \
MAILCATCHER_OVERRIDES_MAILGUN=true \
bundle exec rails s
```

Now you can easily just use last-command recall in your shell to pull up the previous command and add or remove the override easily, without needing to go and look up your Mailgun API key and domain or search back potentially a long way in command history for whenever it was last used.

### Recaptcha

If you want to test things like booking pages, you'll need Google V2 checkbox recaptcha credentials, or use Enterprise V3.

  https://www.google.com/recaptcha/admin

**For V2** run HCMS with:

```shell
RECAPTCHA_SITE_KEY="..." \
RECAPTCHA_SECRET_KEY="..." \
bundle exec rails s
```

Legacy alternatives environment variable names, now deprecated:

* Site key `RECAPTCHA_PUBLIC_KEY`
* Secret key `RECAPTCHA_PRIVATE_KEY`

**For V3** run HCMS with:

```shell
RECAPTCHA_KEY_ID="..." \
RECAPTCHA_GCLOUD_API_KEY="..." \
RECAPTCHA_GCLOUD_PROJECT_ID="..." \
bundle exec rails s
```

In Google Cloud Console, you need to set up a recaptcha key ("key ID") and a Google Cloud API key ("API key") for the recaptcha API calls being made behind the scenes, or use an existing one if you have one. This is all done within what Google Console calls a Project ("project ID"). The Google UI seems to change completely every 5 minutes, but at the time of writing:

* Go to "https://console.cloud.google.com/"
* Make sure you're in the correct Project. Top-left next to the Google Cloud logo should be a project picker. You can create a new Project if you have none, or want a new one just to hold recaptcha stuff; when finished, go back to "https://console.cloud.google.com/" again.
* At the top right is a vertical "..." menu, which should have "Project Settings" (else try to find the project settings somewhere else!) - therein, beneath project name, should be Project ID (typically a dash-case / kebab-case version of the project name). That's for `RECAPTCHA_GCLOUD_PROJECT_ID`.
* Search for "Recaptcha", probably ending up at "https://console.cloud.google.com/security/recaptcha"
* Create a key. No special settings likely needed other than domain names. For local testing you need to add domain "localhost" (or just turn off domain verification) and *will* need to specify that it's a test key in additional settings.
* In the Key Details page the ID is clearly visible. That's for `RECAPTCHA_KEY_ID`.
* Back at https://console.cloud.google.com/ search for "Credentials" (looking for the one under APIs & Services), probably ending up at "https://console.cloud.google.com/apis/credentials"
* Here you can Create Credentials -> API Key and get an API key. That's for `RECAPTCHA_GCLOUD_API_KEY`.
