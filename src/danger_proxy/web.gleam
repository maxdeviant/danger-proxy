import danger_proxy/github
import wisp.{type Request, type Response}

pub type Context {
  Context(
    github_token: github.AccessToken,
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
