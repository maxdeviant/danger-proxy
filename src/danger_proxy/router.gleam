import danger_proxy/github.{type OwnerAndRepo, OwnerAndRepo}
import danger_proxy/web.{type Context, middleware}
import gleam/http
import gleam/http/response
import gleam/io
import gleam/list
import gleam/result.{try}
import gleam/string
import gleam/string_builder
import wisp.{type Request, type Response}

pub fn handle_request(req: Request, ctx: Context) -> Response {
  use req <- middleware(req, ctx)

  case wisp.path_segments(req) {
    ["github", ..segments] -> proxy_github_api_request(req, ctx, segments)
    _ -> wisp.not_found()
  }
}

fn proxy_github_api_request(
  req: Request,
  ctx: Context,
  segments: List(String),
) -> Response {
  let proxy_result = {
    use _ <- try(
      restrict_to_allowed_repos(segments, ctx.allowed_repos)
      |> result.map_error(fn(_) { "Request not allowed." }),
    )

    wisp.log_info(
      "Proxying "
      <> {
        req.method
        |> http.method_to_string
        |> string.uppercase
      }
      <> " /"
      <> string.join(segments, "/")
      <> " to GitHub",
    )

    let github_result =
      github.api_request(ctx.github_token, string.join(segments, "/"))

    github_result
  }

  case proxy_result {
    Ok(response) -> {
      response
      |> response.map(fn(body) {
        body
        |> string_builder.from_string
        |> wisp.Text
      })
    }
    Error(err) -> {
      io.debug(err)
      wisp.internal_server_error()
      |> wisp.string_body("Internal Server Error")
    }
  }
}

type AllowedRequest {
  AllowedRequest(owner: String, repo: String, segments: List(String))
}

fn restrict_to_allowed_repos(
  segments: List(String),
  allowed: List(OwnerAndRepo),
) -> Result(AllowedRequest, Nil) {
  case segments {
    ["repos", owner, repo, ..rest] -> {
      let is_allowed =
        allowed
        |> list.contains(OwnerAndRepo(owner, repo))

      case is_allowed {
        True -> Ok(AllowedRequest(owner, repo, rest))
        False -> Error(Nil)
      }
    }
    _ -> Error(Nil)
  }
}
