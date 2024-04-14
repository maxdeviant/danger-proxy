import bigben/clock
import birl
import danger_proxy/github.{type OwnerAndRepo, OwnerAndRepo}
import danger_proxy/github_rate_limit_tracker
import danger_proxy/web.{type Context, middleware}
import gleam/bit_array
import gleam/http.{type Method, Get}
import gleam/http/response
import gleam/int
import gleam/io
import gleam/list
import gleam/option
import gleam/result.{try}
import gleam/string
import gleam/string_builder
import gleam/uri
import wisp.{type Request, type Response}

pub fn handle_request(req: Request, ctx: Context) -> Response {
  use req <- middleware(req, ctx)

  case wisp.path_segments(req) {
    [] ->
      wisp.ok()
      |> wisp.string_body(
        "Danger Proxy <https://github.com/maxdeviant/danger-proxy>",
      )
    ["rate_limit"] -> rate_limit_status(req, ctx)
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
      restrict_to_allowed_requests(req.method, segments, ctx.allowed_repos)
      |> result.map_error(fn(_) { "Request not allowed." }),
    )

    let query = wisp.get_query(req)

    let request_body =
      req
      |> wisp.read_body_to_bitstring
      |> result.try(bit_array.to_string)

    wisp.log_info(
      "Proxying "
      <> {
        req.method
        |> http.method_to_string
        |> string.uppercase
      }
      <> " /"
      <> string.join(segments, "/")
      <> {
        case query {
          [] -> ""
          query -> "?" <> uri.query_to_string(query)
        }
      }
      <> " to GitHub",
    )

    let github_result =
      github.api_request(
        ctx.github_token,
        req.method,
        string.join(segments, "/"),
        query,
        option.from_result(request_body),
      )

    github_result
  }

  case proxy_result {
    Ok(response) -> {
      case github.parse_rate_limit(response) {
        Ok(rate_limit) -> {
          ctx.github_rate_limit_tracker
          |> github_rate_limit_tracker.update(rate_limit)
        }
        Error(_) -> Nil
      }

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

/// A request to the GitHub API.
type GithubRequest {
  GetAuthenticatedUser
  RepositoryRequest(owner: String, repo: String, segments: List(String))
}

fn restrict_to_allowed_requests(
  method: Method,
  segments: List(String),
  allowed: List(OwnerAndRepo),
) -> Result(GithubRequest, Nil) {
  case #(method, segments) {
    #(Get, ["user"]) -> Ok(GetAuthenticatedUser)
    #(_, ["repos", owner, repo, ..rest]) -> {
      let is_allowed =
        allowed
        |> list.contains(OwnerAndRepo(owner, repo))

      case is_allowed {
        True -> Ok(RepositoryRequest(owner, repo, rest))
        False -> Error(Nil)
      }
    }
    _ -> Error(Nil)
  }
}

fn rate_limit_status(_req: Request, ctx: Context) -> Response {
  let result = {
    let rate_limit =
      ctx.github_rate_limit_tracker
      |> github_rate_limit_tracker.get()

    case rate_limit {
      Ok(rate_limit) -> {
        let now = clock.now(ctx.clock)
        let reset_in = birl.legible_difference(now, rate_limit.reset)

        Ok(
          "Limit: "
          <> int.to_string(rate_limit.limit)
          <> "\nUsed: "
          <> int.to_string(rate_limit.used)
          <> "\nRemaining: "
          <> int.to_string(rate_limit.remaining)
          <> "\nReset "
          <> reset_in,
        )
      }
      Error(Nil) -> Ok("No rate limit set.")
    }
  }

  case result {
    Ok(content) ->
      wisp.ok()
      |> wisp.string_body(content)
    Error(err) -> {
      io.debug(err)
      wisp.internal_server_error()
      |> wisp.string_body("Internal Server Error")
    }
  }
}
