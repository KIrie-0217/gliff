# gliff

[![Package Version](https://img.shields.io/hexpm/v/gliff)](https://hex.pm/packages/gliff)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/gliff/)

A text diffing library for Gleam.

Myers diff, patience diff, unified diff format, patch application, semantic cleanup, and inline highlighting.

## Installation

```sh
gleam add gliff
```

## Quick Start

```gleam
import gliff
import gliff/types.{Delete, Equal, Insert}

pub fn main() {
  let old = "hello\nworld"
  let new = "hello\ngleam"

  let edits = gliff.diff(old, new)
  // [Equal(["hello"]), Delete(["world"]), Insert(["gleam"])]

  let unified = gliff.to_unified(edits, old_name: "a.txt", new_name: "b.txt")
  // "--- a.txt\n+++ b.txt\n@@ -1,2 +1,2 @@\n hello\n-world\n+gleam\n"

  let assert Ok(result) = gliff.apply_patch(old, edits)
  // "hello\ngleam"
}
```

## API

### Diffing

| Function | Description |
|---|---|
| `diff(old, new)` | Line-level diff (Myers) |
| `diff_chars(old, new)` | Character-level diff |
| `diff_words(old, new)` | Word-level diff |
| `diff_myers(old, new)` | Explicit Myers algorithm |
| `diff_patience(old, new)` | Patience algorithm (anchors on unique lines) |
| `diff_with(old, new, config)` | Configurable: algorithm + cleanup + budget |
| `diff_chars_with(old, new, config)` | Character-level with config |
| `default_config()` | `DiffConfig(Myers, NoCleanup, 0)` |

### Output & Patching

| Function | Description |
|---|---|
| `to_unified(edits, old_name:, new_name:)` | Format as unified diff string |
| `from_unified(input)` | Parse unified diff into hunks |
| `apply_patch(text, edits)` | Apply edits to produce target text |

### Post-Processing

| Function | Description |
|---|---|
| `cleanup_semantic(edits)` | Eliminate trivial equalities, merge edits |
| `cleanup_semantic_lossless(edits)` | Shift edits to natural boundaries |
| `similarity(edits)` | Ratio from 0.0 (different) to 1.0 (identical) |
| `inline_highlight(edits)` | Character-level spans within changed lines |

## Types

All types live in `gliff/types`:

```gleam
import gliff/types.{
  type Edit, Equal, Insert, Delete,
  type Hunk, Hunk,
  type InlineEdit, InlineEqual, InlineDelete, InlineInsert,
  type Span, Changed, Unchanged,
  type DiffConfig, DiffConfig,
  type Algorithm, Myers, Patience,
  type Cleanup, NoCleanup, SemanticCleanup, SemanticLosslessCleanup,
  type DiffResult, Complete, Truncated,
}
```

## Examples

See [`examples/`](examples/) for runnable code with annotated output:

- [`basic.gleam`](examples/basic.gleam) — diff, unified output, patch, similarity
- [`word_diff.gleam`](examples/word_diff.gleam) — word-level diffing
- [`patience_diff.gleam`](examples/patience_diff.gleam) — Myers vs Patience comparison
- [`inline_highlight.gleam`](examples/inline_highlight.gleam) — character-level change spans
- [`configurable.gleam`](examples/configurable.gleam) — algorithm, cleanup, and budget config

## Development

```sh
gleam test                     # Erlang
gleam test --target javascript # JavaScript
```

## License

MIT
