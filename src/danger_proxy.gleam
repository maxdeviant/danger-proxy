import bigben/clock
import danger_proxy/github
import danger_proxy/router
import danger_proxy/web.{Context}
import gleam/erlang/process
import gleam/list
import gleam/result
import gleam/string
import glenvy/dotenv
import glenvy/env
import mist
import danger_proxy/github_rate_limit_tracker
import wisp

pub fn main() {
  let _ = dotenv.load()

  wisp.configure_logger()

  let assert Ok(secret_key_base) =
    env.get_string("SECRET_KEY_BASE")
    |> result.map_error(fn(_) {
      "Missing environment variable: 'SECRET_KEY_BASE'"
    })

  let assert Ok(github_api_token) =
    env.get_string("GITHUB_API_TOKEN")
    |> result.map(github.AccessToken)
    |> result.map_error(fn(_) {
      "Missing environment variable: 'GITHUB_API_TOKEN'"
    })

  let assert Ok(allowed_repos) =
    env.get_string("ALLOWED_REPOS")
    |> result.try(fn(value) {
      value
      |> string.split(on: ",")
      |> list.try_map(github.parse_owner_and_repo)
    })
    |> result.map_error(fn(_) {
      "Missing environment variable: 'ALLOWED_REPOS'"
    })

  let assert Ok(github_rate_limit_tracker) = github_rate_limit_tracker.start()

  let ctx =
    Context(
      clock: clock.new(),
      github_token: github_api_token,
      github_rate_limit_tracker: github_rate_limit_tracker,
      allowed_repos: allowed_repos,
    )

  let port =
    env.get_int("PORT")
    |> result.unwrap(3000)

  let assert Ok(_) =
    wisp.mist_handler(router.handle_request(_, ctx), secret_key_base)
    |> mist.new
    |> mist.port(port)
    |> mist.start_http

  process.sleep_forever()
  |> Ok
}
