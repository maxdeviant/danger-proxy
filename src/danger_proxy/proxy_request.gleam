import gleam/http
import gleam/string
import gleam/uri
import wisp.{type Request}

/// A request to be proxied to another location.
pub type ProxyRequest {
  ProxyRequest(
    method: http.Method,
    path: String,
    query: List(#(String, String)),
  )
}

/// Returns a new `ProxyRequest` from the given `Request`.
pub fn from_request(req: Request, path_segments: List(String)) -> ProxyRequest {
  ProxyRequest(
    method: req.method,
    path: string.join(path_segments, "/"),
    query: wisp.get_query(req),
  )
}

/// Returns the string representation of the given `ProxyRequest.
pub fn to_string(req: ProxyRequest) -> String {
  let method =
    req.method
    |> http.method_to_string
    |> string.uppercase

  method
  <> " /"
  <> req.path
  <> {
    case req.query {
      [] -> ""
      query -> "?" <> uri.query_to_string(query)
    }
  }
}
