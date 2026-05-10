//// Shared type definitions for the gliff diffing library.
////
//// Import this module to access all types used in gliff's public API.

/// A single-element edit produced by the diff algorithm internally.
/// Grouped into `Edit` before being returned to users.
pub type RawEdit {
  RawEqual(value: String)
  RawInsert(value: String)
  RawDelete(value: String)
}

/// A grouped edit operation representing one or more contiguous lines
/// (or tokens) that share the same change type.
pub type Edit {
  /// Lines present in both old and new text.
  Equal(lines: List(String))
  /// Lines added in the new text.
  Insert(lines: List(String))
  /// Lines removed from the old text.
  Delete(lines: List(String))
}

/// A hunk in unified diff format, representing a localized group of changes
/// with surrounding context lines.
pub type Hunk {
  Hunk(
    /// 1-indexed starting line in the old file.
    old_start: Int,
    /// Number of lines from the old file in this hunk.
    old_count: Int,
    /// 1-indexed starting line in the new file.
    new_start: Int,
    /// Number of lines from the new file in this hunk.
    new_count: Int,
    /// The edit operations within this hunk.
    edits: List(Edit),
  )
}

/// A segment within a line for inline change highlighting.
pub type Span {
  /// Text that is the same in both old and new.
  Unchanged(text: String)
  /// Text that differs between old and new.
  Changed(text: String)
}

/// An edit enriched with character-level highlighting information.
pub type InlineEdit {
  /// A line that is unchanged between old and new.
  InlineEqual(lines: List(String))
  /// A deleted line with spans showing which characters were removed.
  InlineDelete(spans: List(Span))
  /// An inserted line with spans showing which characters were added.
  InlineInsert(spans: List(Span))
}

/// The diff algorithm to use.
pub type Algorithm {
  /// Myers O(ND) algorithm — optimal edit distance, fast for similar texts.
  Myers
  /// Patience algorithm — anchors on unique lines for more readable output.
  Patience
}

/// Post-processing cleanup mode to apply after diffing.
pub type Cleanup {
  /// No cleanup — return the raw diff result.
  NoCleanup
  /// Eliminate trivial equalities and merge adjacent edits.
  SemanticCleanup
  /// Shift edit boundaries to natural positions (word, sentence, line boundaries).
  SemanticLosslessCleanup
}

/// Configuration for diff operations.
pub type DiffConfig {
  DiffConfig(
    /// Which algorithm to use.
    algorithm: Algorithm,
    /// Post-processing cleanup mode.
    cleanup: Cleanup,
    /// Maximum iterations before fallback. 0 means unlimited.
    max_iterations: Int,
  )
}

/// The result of a configurable diff operation.
pub type DiffResult {
  /// The diff completed within the iteration budget.
  Complete(edits: List(Edit))
  /// The iteration budget was exceeded; result is a valid but approximate diff.
  Truncated(edits: List(Edit))
}
