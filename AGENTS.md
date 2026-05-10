# gliff

> A text diffing library for Gleam.
> Myers diff algorithm, unified diff format, and patch operations.

## Project Overview

- Package name: `gliff`
- Language: Gleam (targets both Erlang and JavaScript)
- Purpose: compute text diffs, format as unified diff, apply patches
- No FFI — pure Gleam implementation

## Architecture

### Core algorithm

Myers diff (Eugene W. Myers, 1986) — computes the shortest edit script
(minimum number of insertions and deletions) between two sequences.

Reference: "An O(ND) Difference Algorithm and Its Variations"

### Module structure

| Module | Responsibility |
|---|---|
| `gliff` | Public API (diff, diff_chars, to_unified, from_unified, apply_patch) |
| `gliff/internal/myers` | Myers diff algorithm implementation |
| `gliff/internal/unified` | Unified diff format generation and parsing |
| `gliff/internal/patch` | Patch application logic |

### Types

```gleam
pub type Edit {
  Equal(lines: List(String))
  Insert(lines: List(String))
  Delete(lines: List(String))
}

pub type Hunk {
  Hunk(
    old_start: Int,
    old_count: Int,
    new_start: Int,
    new_count: Int,
    edits: List(Edit),
  )
}
```

## Development Guidelines

### Development flow

Write implementation → write tests → pass tests → move on.

Always run `gleam format src test` before committing.

### Design principles

- Pure Gleam — no `@external` bindings. Must work on both BEAM and JS.
- Zero dependencies beyond `gleam_stdlib`.
- Correctness over performance — match `diff -u` output exactly.
- Composable API — edits are data, not side effects.

### Testing strategy

- Property: `apply_patch(old, diff(old, new)) == Ok(new)` for all inputs
- Golden tests: compare output against `diff -u` for known inputs
- Edge cases: empty strings, identical strings, completely different strings,
  single character differences, large inputs
