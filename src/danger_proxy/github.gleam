import birl.{type Time}
import gleam/hackney
import gleam/http.{type Method, Https}
import gleam/http/request
import gleam/http/response.{type Response}
import gleam/int
import gleam/io
import gleam/option.{type Option, None, Some}
import gleam/result.{try}
import gleam/string

pub type AccessToken {
  AccessToken(String)
}

pub type OwnerAndRepo {
  OwnerAndRepo(owner: String, repo: String)
}

/// Parses the given string into an `OwnerAndRepo`.
///
/// The input should be in the form `{owner}/{repo}`.
pub fn parse_owner_and_repo(input: String) -> Result(OwnerAndRepo, Nil) {
  let parts = string.split(input, on: "/")
  case parts {
    [owner, repo] -> {
      let owner = string.trim(owner)
      let repo = string.trim(repo)
      Ok(OwnerAndRepo(owner, repo))
    }
    _ -> Error(Nil)
  }
}

/// A rate limit.
pub type RateLimit {
  RateLimit(
    /// The maximum number of requests that you can make per hour.
    limit: Int,
    /// The number of requests remaining in the current rate limit window.
    remaining: Int,
    /// The number of requests you have made in the current rate limit window.
    used: Int,
    /// The time at which the current rate limit window resets, in UTC.
    reset: Time,
    /// The rate limit resource that the request counted against.
    resource: String,
  )
}

/// Parses a `RateLimit` from the headers on the given `Response`.
pub fn parse_rate_limit(res: Response(a)) -> Result(RateLimit, Nil) {
  use limit <- try(
    res
    |> response.get_header("x-ratelimit-limit")
    |> result.try(int.parse),
  )
  use remaining <- try(
    res
    |> response.get_header("x-ratelimit-remaining")
    |> result.try(int.parse),
  )
  use used <- try(
    res
    |> response.get_header("x-ratelimit-used")
    |> result.try(int.parse),
  )
  use reset <- try(
    res
    |> response.get_header("x-ratelimit-reset")
    |> result.try(int.parse)
    |> result.map(birl.from_unix),
  )
  use resource <- try(
    res
    |> response.get_header("x-ratelimit-resource"),
  )

  Ok(RateLimit(
    limit: limit,
    remaining: remaining,
    used: used,
    reset: reset,
    resource: resource,
  ))
}

pub fn api_request(
  token: AccessToken,
  method: Method,
  url: String,
  query: List(#(String, String)),
  body: Option(String),
) -> Result(Response(String), String) {
  let AccessToken(token) = token

  let request =
    request.new()
    |> request.set_scheme(Https)
    |> request.set_host("api.github.com")
    |> request.set_method(method)
    |> request.set_path(url)
    |> request.set_query(query)
    |> request.set_header("authorization", "Bearer " <> token)
    |> fn(req) {
      case body {
        Some(body) ->
          req
          |> request.set_body(body)
        None -> req
      }
    }

  use response <- try(
    request
    |> hackney.send
    |> result.map_error(fn(err) {
      io.debug(err)
      "Request failed"
    }),
  )

  Ok(response)
}
