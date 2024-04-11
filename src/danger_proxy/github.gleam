import gleam/hackney
import gleam/http.{type Method, Https}
import gleam/http/request
import gleam/http/response.{type Response}
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
