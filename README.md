# HCMS

This is a _very simple_ content management system designed for small web sites. Pages are edited with Imperavi's [Redactor](https://imperavi.com/redactor/) editor or optionally (per page) just with raw HTML. File uploads are supported via the [CarrierWave](https://github.com/carrierwaveuploader/carrierwave) gem, supporting storage locations such as local filesystem or Amazon S3.

HCMS source code is managed by Git and hosted by GitHub; site styling is done by modifying the Rails static CSS, static images and layout templates in the CMS using a branch off `master` or a fork.

## Route overview

### Admin

All routes at `/hcms/...` are for editing pages and so-on.

### Public

All other routes from `/` are for public page views.

## Configuration

### Heroku configuration

#### Rails

HCMS can be deployed to Heroku by-the-book:

* https://devcenter.heroku.com/articles/getting-started-with-rails4

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
heroku --app your-appname-1234 config:set AWS_ACCESS_KEY_ID=xxx AWS_SECRET_ACCESS_KEY=yyy
heroku --app your-appname-1234 config:set AWS_S3_REGION=region # e.g. 'eu-west-1'
heroku --app your-appname-1234 config:set AWS_S3_BUCKET_NAME=s3-bucket-name
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

If you want to test things like booking pages, you'll need Google V2 checkbox recaptcha credentials.

  https://www.google.com/recaptcha/admin

Run HCMS with:

```
RECAPTCHA_PUBLIC_KEY="..." RECAPTCHA_PRIVATE_KEY="..." be rails s
```
