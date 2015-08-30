# HMCS

This is a very simple content management system.


## Admin

All routes at /admin are for editing pages and so-on.


## Public

All other routes from / are for public page views.


## Use with S3

If you want to use Amazon S3 storage instead of the local filesystem for uploaded files and documents in the Redactor editor - e.g. because you're on Heroku - then you need to set up some environment variables. In the presence of variable `AWS_ACCESS_KEY_ID` the system switches Carrierwave over to Amazon S3 storage. On Heroku, you'll need to set up Heroku configuration variables with the relevant credentials. See this page for help:

  https://devcenter.heroku.com/articles/s3

In brief:

```bash
heroku config:set AWS_ACCESS_KEY_ID=xxx AWS_SECRET_ACCESS_KEY=yyy
heroku config:set AWS_S3_REGION=region # e.g. 'eu-west-1'
heroku config:set AWS_S3_BUCKET_NAME=s3-bucket-name
```

The system variables you set should match the above names. Ideally set up a brand new IAM user for the access ID and key; assigning the out-of-the-box S3 'grant all' policy should be sufficient for that user.
