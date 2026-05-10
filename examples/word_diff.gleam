//// Output:
////
////   === Word-Level Diff ===
////   Old: The quick brown fox jumps over the lazy dog
////   New: The slow brown fox leaps over the happy dog
////
////   The [-quick-]{+slow+} brown fox [-jumps-]{+leaps+} over the [-lazy-]{+happy+} dog

import gleam/io
import gliff
import gliff/types.{type Edit, Delete, Equal, Insert}

pub fn main() {
  let old = "The quick brown fox jumps over the lazy dog"
  let new = "The slow brown fox leaps over the happy dog"

  io.println("=== Word-Level Diff ===")
  io.println("Old: " <> old)
  io.println("New: " <> new)
  io.println("")

  let edits = gliff.diff_words(old, new)
  print_word_edits(edits)
}

fn print_word_edits(edits: List(Edit)) -> Nil {
  case edits {
    [] -> {
      io.println("")
      Nil
    }
    [edit, ..rest] -> {
      case edit {
        Equal(tokens) -> print_tokens(tokens)
        Delete(tokens) -> {
          io.print("[-")
          print_tokens(tokens)
          io.print("-]")
        }
        Insert(tokens) -> {
          io.print("{+")
          print_tokens(tokens)
          io.print("+}")
        }
      }
      print_word_edits(rest)
    }
  }
}

fn print_tokens(tokens: List(String)) -> Nil {
  case tokens {
    [] -> Nil
    [t, ..rest] -> {
      io.print(t)
      print_tokens(rest)
    }
  }
}
