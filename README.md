# HCMS

This is a _very simple_ content management system designed for small web sites. Pages are edited with Imperavi's [Redactor](https://imperavi.com/redactor/) editor or optionally (per page) just with raw HTML. File uploads are supported via the [CarrierWave](https://github.com/carrierwaveuploader/carrierwave) gem, supporting storage locations such as local filesystem or Amazon S3.

HCMS source code is managed by Git and hosted by GitHub; site styling is done by modifying the Rails static CSS, static images and layout templates in the CMS using a branch off `master` or a fork.

## Setup

Install gems, set up the database and create a starting point home page.

```shell
bundle install
bundle exec rake db:create db:migrate
bundle exec rake setup:home
```

Now visit the site (e.g. visit `http://localhost:3000`) to see the default home page, proving that the application is working normally. Add `/hcms` to the URL to be given a login page, then follow the "sign up" link to create an admin account. Presently, only one account is supported.

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

#### Uploaded file storage

You'll need to use Amazon S3 on Heroku - see below.

### File storage with Amazon S3

If you want to use Amazon S3 storage instead of the web server's local filesystem for uploaded files and documents - e.g. because you're on Heroku, where the filesystem is transient rather than persistent - then you must set some environment variables to tell the CarrierWave upload handler what to do.

First, you'll need to set up a bucket using the Amazon S3 web interface. Ideally set up a brand new IAM user for the access ID and key. The interface for this is rather complex, but at least assigning an out-of-the-box S3 'grant all' policy should be sufficient for that user. In any case, through the Amazon console you'll know your access ID and secret keys, you'll have chosen a hosting region for your S3 bucket and you'll have given it a name.

Next set variable `AWS_ACCESS_KEY_ID` to switch CarrierWave over to Amazon S3 storage. `AWS_SECRET_ACCESS_KEY` gives CarrierWave the S3 secret key, `AWS_S3_REGION` gives it the region (e.g. `eu-west-1`) and `AWS_S3_BUCKET_NAME` tells it the name of the bucket you created. On Heroku, you set these with the `heroku` command. See this page for help:

  https://devcenter.heroku.com/articles/s3

In brief:

```bash
heroku config:set AWS_ACCESS_KEY_ID=xxx AWS_SECRET_ACCESS_KEY=yyy  --app your-appname-1234
heroku config:set AWS_S3_REGION=region # e.g. 'eu-west-1'          --app your-appname-1234
heroku config:set AWS_S3_BUCKET_NAME=s3-bucket-name                --app your-appname-1234
```

### GTM

A Google site tag snippet is included for your AD ID (`9xxyyyzzz` or some similar number) if you specify the GOOGLE_AD_ID variable.

```bash
heroku config:set GOOGLE_AD_ID=9xxyyyzzz --app your-appname-1234
```

## Development

### Mailcatcher

ActiveMailer is configured for use with [MailCatcher](https://github.com/sj26/mailcatcher). You should install this gem separately, as it has requirements on gems such as Rake or Thin which are mutually incompatible with the bundle used by HCMS.

```
gem install mailcatcher
mailcatcher
```

A daemon will listen at localhost port 1080 for a web UI showing received mail, with an SMTP server on localhost port 1025 - this is the thing that HCMS is configured to communicate with for local development.

### Recaptcha

If you want to test things like booking pages, you'll need Google V2 checkbox recaptcha credentials, or use Enterprise V3.

  https://www.google.com/recaptcha/admin

**For V2** run HCMS with:

```
RECAPTCHA_SITE_KEY="..." RECAPTCHA_SECRET_KEY="..." be rails s
```

Legacy alternatives environment variable names, now deprecated:

* Site key `RECAPTCHA_PUBLIC_KEY`
* Secret key `RECAPTCHA_PRIVATE_KEY`

**For V3** run HCMS with:

```
RECAPTCHA_KEY_ID="..." RECAPTCHA_GCLOUD_API_KEY="..." RECAPTCHA_GCLOUD_PROJECT_ID="..." be rails s
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
