# Record some information about a request for stats / curiosity only. For
# things like 500 errors or similar, Sentry is the go-to.
#
# - Anonymous; no PII, IP, etc.
# - Time.date
# - Path requested and controller+action that this reached
# - Referrer address if available, so we know how people are reaching us
# - Params data
# - Outcome (our response HTTP status)
#
# Most of the time this is done via ApplicationController after-action with a
# set of conditions:
#
# - GET requests only, XHR also excluded even if a GET
# - 200 OK responses only, so e.g. redirections not included
# - Non-bots only according to Browser gem; metrics may be skewed as a result
#   of mis-detection, especially in an era of malicious, lying AI crawlers!
# - Does not record impressions if there's an admin logged in, so admins don't
#   skew their own impression data
#
# The redirections controller also records 302 or 404 outcomes, so that we can
# see if people are trying to reach us on URLs we don't map but should. Most
# of these entries though will probably be from attacking bots trying to probe
# for vulnerabilities.
#
class PageImpression < ApplicationRecord
  default_scope -> { order(id: :asc) }

  def title; end # This is for tests only
end
