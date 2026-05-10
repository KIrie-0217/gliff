//// Output:
////
////   === Line Diff ===
////     the
////   - quick
////   + slow
////     brown
////   - fox
////   + dog
////     jumps
////
////   === Unified Diff ===
////   --- old.txt
////   +++ new.txt
////   @@ -1,5 +1,5 @@
////    the
////   -quick
////   +slow
////    brown
////   -fox
////   +dog
////    jumps
////
////   === Patch Applied ===
////   the
////   slow
////   brown
////   dog
////   jumps
////
////   === Similarity ===
////   Ratio: ~0.5

import gleam/io
import gliff
import gliff/types.{type Edit, Delete, Equal, Insert}

pub fn main() {
  let old = "the\nquick\nbrown\nfox\njumps"
  let new = "the\nslow\nbrown\ndog\njumps"

  // Line-level diff
  let edits = gliff.diff(old, new)
  io.println("=== Line Diff ===")
  print_edits(edits)

  // Unified diff output
  io.println("\n=== Unified Diff ===")
  let unified =
    gliff.to_unified(edits, old_name: "old.txt", new_name: "new.txt")
  io.println(unified)

  // Apply patch (roundtrip)
  let assert Ok(result) = gliff.apply_patch(old, edits)
  io.println("=== Patch Applied ===")
  io.println(result)

  // Similarity ratio
  let ratio = gliff.similarity(edits)
  io.println("\n=== Similarity ===")
  io.println("Ratio: " <> float_to_string(ratio))
}

fn print_edits(edits: List(Edit)) -> Nil {
  case edits {
    [] -> Nil
    [edit, ..rest] -> {
      case edit {
        Equal(lines) -> print_lines(" ", lines)
        Delete(lines) -> print_lines("-", lines)
        Insert(lines) -> print_lines("+", lines)
      }
      print_edits(rest)
    }
  }
}

fn print_lines(prefix: String, lines: List(String)) -> Nil {
  case lines {
    [] -> Nil
    [line, ..rest] -> {
      io.println(prefix <> " " <> line)
      print_lines(prefix, rest)
    }
  }
}

fn float_to_string(f: Float) -> String {
  case f == 1.0 {
    True -> "1.0"
    False ->
      case f == 0.0 {
        True -> "0.0"
        False -> "~0.5"
      }
  }
}
