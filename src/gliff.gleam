//// gliff — A text diffing library for Gleam.
////
//// Provides Myers and Patience diff algorithms, unified diff formatting,
//// patch application, semantic cleanup, and inline highlighting.

import gleam/list
import gleam/string
import gliff/internal/budget
import gliff/internal/cleanup
import gliff/internal/inline
import gliff/internal/myers
import gliff/internal/patch
import gliff/internal/patience
import gliff/internal/similarity
import gliff/internal/tokenize
import gliff/internal/unified
import gliff/types.{
  type DiffConfig, type DiffResult, type Edit, type Hunk, type InlineEdit,
  type RawEdit, Complete, Delete, DiffConfig, Equal, Insert, Myers, NoCleanup,
  Patience, RawDelete, RawEqual, RawInsert, SemanticCleanup,
  SemanticLosslessCleanup, Truncated,
}

/// Compute a line-level diff between two strings using the Myers algorithm.
///
/// Returns a list of edit operations (Equal, Insert, Delete) where each
/// operation contains one or more contiguous lines.
pub fn diff(old: String, new: String) -> List(Edit) {
  let old_lines = split_lines(old)
  let new_lines = split_lines(new)
  let raw_edits = myers.diff(old_lines, new_lines)
  group_edits(raw_edits)
}

/// Compute a character-level diff between two strings using the Myers algorithm.
///
/// Each element in the returned edit list represents one or more contiguous
/// grapheme clusters that share the same edit type.
pub fn diff_chars(old: String, new: String) -> List(Edit) {
  let old_chars = string.to_graphemes(old)
  let new_chars = string.to_graphemes(new)
  let raw_edits = myers.diff(old_chars, new_chars)
  group_edits(raw_edits)
}

/// Format a list of edits as a unified diff string.
///
/// The output matches the format produced by `diff -u`, with 3 lines of
/// context around each change. `old_name` and `new_name` appear in the
/// `---` and `+++` header lines.
pub fn to_unified(
  edits: List(Edit),
  old_name old_name: String,
  new_name new_name: String,
) -> String {
  unified.to_unified(edits, old_name:, new_name:)
}

/// Parse a unified diff string into a list of hunks.
///
/// Accepts the standard format produced by `diff -u` or `to_unified`.
/// Returns an error if the input is malformed.
pub fn from_unified(input: String) -> Result(List(Hunk), String) {
  unified.from_unified(input)
}

/// Apply edit operations to a text string to produce the target text.
///
/// The fundamental property is:
/// `apply_patch(old, diff(old, new)) == Ok(new)`
///
/// Returns an error if the text doesn't match the expected content
/// described by the Equal and Delete operations.
pub fn apply_patch(text: String, edits: List(Edit)) -> Result(String, String) {
  patch.apply_patch(text, edits)
}

/// Compute the similarity ratio between two texts from their diff result.
///
/// Returns a value between 0.0 (completely different) and 1.0 (identical).
/// Calculated as `2 * matching_elements / total_elements`.
pub fn similarity(edits: List(Edit)) -> Float {
  similarity.ratio(edits)
}

/// Compute a line-level diff using the Myers algorithm (explicit alias for `diff`).
pub fn diff_myers(old: String, new: String) -> List(Edit) {
  diff(old, new)
}

/// Compute a line-level diff using the Patience algorithm.
///
/// Patience diff anchors on lines that appear exactly once in both texts,
/// then recursively diffs the gaps. This often produces more readable
/// output for code changes where blocks are reordered.
pub fn diff_patience(old: String, new: String) -> List(Edit) {
  let old_lines = split_lines(old)
  let new_lines = split_lines(new)
  let raw_edits = patience.diff(old_lines, new_lines)
  group_edits(raw_edits)
}

/// Compute a word-level diff between two strings.
///
/// Tokenizes input by whitespace boundaries (preserving whitespace as
/// separate tokens), then diffs the token sequences. Each edit contains
/// one or more word/whitespace tokens.
pub fn diff_words(old: String, new: String) -> List(Edit) {
  let old_tokens = tokenize.words(old)
  let new_tokens = tokenize.words(new)
  let raw_edits = myers.diff(old_tokens, new_tokens)
  group_edits(raw_edits)
}

/// Eliminate trivial equalities and merge adjacent edits.
///
/// Removes small Equal sections that are surrounded by larger changes,
/// absorbing them into the Delete and Insert operations. This produces
/// fewer, larger edit blocks that are easier to read.
pub fn cleanup_semantic(edits: List(Edit)) -> List(Edit) {
  cleanup.semantic(edits)
}

/// Shift edit boundaries to natural positions without changing semantics.
///
/// Moves edit boundaries to align with word boundaries, sentence endings,
/// or blank lines based on a scoring system. The resulting diff applies
/// identically but reads more naturally.
pub fn cleanup_semantic_lossless(edits: List(Edit)) -> List(Edit) {
  cleanup.semantic_lossless(edits)
}

/// Enrich line-level edits with character-level change highlighting.
///
/// For adjacent Delete/Insert pairs, computes a character-level sub-diff
/// and returns spans marking which characters actually changed. Equal
/// edits pass through as InlineEqual.
pub fn inline_highlight(edits: List(Edit)) -> List(InlineEdit) {
  inline.highlight(edits)
}

/// Create a default diff configuration.
///
/// Returns `DiffConfig(algorithm: Myers, cleanup: NoCleanup, max_iterations: 0)`
/// where `max_iterations: 0` means unlimited computation.
pub fn default_config() -> DiffConfig {
  DiffConfig(algorithm: Myers, cleanup: NoCleanup, max_iterations: 0)
}

/// Compute a line-level diff with full configuration.
///
/// Allows selecting the algorithm, cleanup mode, and iteration budget.
/// Returns `Complete` if the diff finished normally, or `Truncated` if
/// the iteration budget was exceeded (in which case a crude but correct
/// fallback diff is returned).
pub fn diff_with(old: String, new: String, config: DiffConfig) -> DiffResult {
  let old_tokens = split_lines(old)
  let new_tokens = split_lines(new)
  let b = budget.from_max(config.max_iterations)

  let #(raw_edits, complete) = case config.algorithm {
    Myers -> myers.diff_with_budget(old_tokens, new_tokens, b)
    Patience -> #(patience.diff(old_tokens, new_tokens), True)
  }

  let edits = group_edits(raw_edits)
  let edits_cleaned = apply_cleanup(edits, config.cleanup)

  case complete {
    True -> Complete(edits: edits_cleaned)
    False -> Truncated(edits: edits_cleaned)
  }
}

/// Compute a character-level diff with full configuration.
///
/// Same as `diff_with` but operates on grapheme clusters instead of lines.
pub fn diff_chars_with(
  old: String,
  new: String,
  config: DiffConfig,
) -> DiffResult {
  let old_chars = string.to_graphemes(old)
  let new_chars = string.to_graphemes(new)
  let b = budget.from_max(config.max_iterations)

  let #(raw_edits, complete) = case config.algorithm {
    Myers -> myers.diff_with_budget(old_chars, new_chars, b)
    Patience -> #(patience.diff(old_chars, new_chars), True)
  }

  let edits = group_edits(raw_edits)
  let edits_cleaned = apply_cleanup(edits, config.cleanup)

  case complete {
    True -> Complete(edits: edits_cleaned)
    False -> Truncated(edits: edits_cleaned)
  }
}

fn apply_cleanup(edits: List(Edit), mode: types.Cleanup) -> List(Edit) {
  case mode {
    NoCleanup -> edits
    SemanticCleanup -> cleanup.semantic(edits)
    SemanticLosslessCleanup -> cleanup.semantic_lossless(edits)
  }
}

fn split_lines(text: String) -> List(String) {
  case text {
    "" -> []
    _ -> string.split(text, "\n")
  }
}

fn group_edits(raw: List(RawEdit)) -> List(Edit) {
  group_edits_loop(raw, [])
  |> list.reverse
}

fn group_edits_loop(raw: List(RawEdit), acc: List(Edit)) -> List(Edit) {
  case raw {
    [] -> acc
    [RawEqual(v), ..rest] -> {
      let #(equals, remaining) = collect_equals(rest, [v])
      group_edits_loop(remaining, [Equal(list.reverse(equals)), ..acc])
    }
    [RawInsert(v), ..rest] -> {
      let #(inserts, remaining) = collect_inserts(rest, [v])
      group_edits_loop(remaining, [Insert(list.reverse(inserts)), ..acc])
    }
    [RawDelete(v), ..rest] -> {
      let #(deletes, remaining) = collect_deletes(rest, [v])
      group_edits_loop(remaining, [Delete(list.reverse(deletes)), ..acc])
    }
  }
}

fn collect_equals(
  raw: List(RawEdit),
  acc: List(String),
) -> #(List(String), List(RawEdit)) {
  case raw {
    [RawEqual(v), ..rest] -> collect_equals(rest, [v, ..acc])
    _ -> #(acc, raw)
  }
}

fn collect_inserts(
  raw: List(RawEdit),
  acc: List(String),
) -> #(List(String), List(RawEdit)) {
  case raw {
    [RawInsert(v), ..rest] -> collect_inserts(rest, [v, ..acc])
    _ -> #(acc, raw)
  }
}

fn collect_deletes(
  raw: List(RawEdit),
  acc: List(String),
) -> #(List(String), List(RawEdit)) {
  case raw {
    [RawDelete(v), ..rest] -> collect_deletes(rest, [v, ..acc])
    _ -> #(acc, raw)
  }
}
