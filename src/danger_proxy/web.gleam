import bigben/clock.{type Clock}
import danger_proxy/github
import danger_proxy/github_rate_limit_tracker.{type GithubRateLimitTracker}
import wisp.{type Request, type Response}

pub type Context {
  Context(
    clock: Clock,
    github_token: github.AccessToken,
    github_rate_limit_tracker: GithubRateLimitTracker,
    allowed_repos: List(github.OwnerAndRepo),
  )
}

pub fn middleware(
  req: Request,
  _ctx: Context,
  next: fn(Request) -> Response,
) -> Response {
  use <- wisp.log_request(req)
  use <- wisp.rescue_crashes

  next(req)
}
