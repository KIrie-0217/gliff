//// Output:
////
////   Old: The cat sat on the mat
////   New: The bat sat on the hat
////
////   === Inline Highlighting ===
////   - The [c]at sat on the [m]at
////   + The [b]at sat on the [h]at

import gleam/io
import gliff
import gliff/types.{
  type InlineEdit, type Span, Changed, InlineDelete, InlineEqual, InlineInsert,
  Unchanged,
}

pub fn main() {
  let old = "The cat sat on the mat"
  let new = "The bat sat on the hat"

  io.println("Old: " <> old)
  io.println("New: " <> new)
  io.println("")

  let edits = gliff.diff(old, new)
  let inline = gliff.inline_highlight(edits)

  io.println("=== Inline Highlighting ===")
  print_inline(inline)
}

fn print_inline(edits: List(InlineEdit)) -> Nil {
  case edits {
    [] -> Nil
    [edit, ..rest] -> {
      case edit {
        InlineEqual(lines) -> {
          io.println("  " <> join(lines, "\n"))
        }
        InlineDelete(spans) -> {
          io.print("- ")
          print_spans(spans)
          io.println("")
        }
        InlineInsert(spans) -> {
          io.print("+ ")
          print_spans(spans)
          io.println("")
        }
      }
      print_inline(rest)
    }
  }
}

fn print_spans(spans: List(Span)) -> Nil {
  case spans {
    [] -> Nil
    [span, ..rest] -> {
      case span {
        Unchanged(text) -> io.print(text)
        Changed(text) -> io.print("[" <> text <> "]")
      }
      print_spans(rest)
    }
  }
}

fn join(items: List(String), sep: String) -> String {
  case items {
    [] -> ""
    [only] -> only
    [first, ..rest] -> first <> sep <> join(rest, sep)
  }
}
