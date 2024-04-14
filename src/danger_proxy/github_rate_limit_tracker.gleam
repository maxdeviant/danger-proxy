import danger_proxy/github.{type RateLimit}
import gleam/otp/actor
import gleam/result
import shakespeare/actors/key_value.{type KeyValueActor}

/// A tracker for GitHub API rate limits.
pub opaque type GithubRateLimitTracker {
  GithubRateLimitTracker(actor: KeyValueActor(RateLimit))
}

/// Starts a new `GithubRateLimitTracker`.
pub fn start() -> Result(GithubRateLimitTracker, actor.StartError) {
  key_value.start()
  |> result.map(GithubRateLimitTracker)
}

/// Updates the `GithubRateLimitTracker` with the given rate limit.
pub fn update(tracker: GithubRateLimitTracker, limit: RateLimit) {
  key_value.set(tracker.actor, limit.resource, limit)
}

/// Gets the latest rate limit from the `GithubRateLimitTracker`.
pub fn get(tracker: GithubRateLimitTracker) -> Result(RateLimit, Nil) {
  key_value.get(tracker.actor, "core")
}
