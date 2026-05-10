import gleam/int
import gleam/list
import gleam/string
import gliff/internal/myers
import gliff/types.{type Edit, type RawEdit, Delete, Equal, Insert, RawEqual}

pub fn ratio(edits: List(Edit)) -> Float {
  let #(matching, total) = count(edits, 0, 0)
  case total {
    0 -> 1.0
    _ -> int.to_float(2 * matching) /. int.to_float(total)
  }
}

fn count(edits: List(Edit), matching: Int, total: Int) -> #(Int, Int) {
  case edits {
    [] -> #(matching, total)
    [edit, ..rest] -> {
      let n = list.length(lines_of(edit))
      case edit {
        Equal(_) -> count(rest, matching + n, total + n + n)
        Delete(_) -> count(rest, matching, total + n)
        Insert(_) -> count(rest, matching, total + n)
      }
    }
  }
}

fn lines_of(edit: Edit) -> List(String) {
  case edit {
    Equal(lines) -> lines
    Insert(lines) -> lines
    Delete(lines) -> lines
  }
}

pub fn line_similarity(a: String, b: String) -> Float {
  let a_chars = string.to_graphemes(a)
  let b_chars = string.to_graphemes(b)
  let total = list.length(a_chars) + list.length(b_chars)
  case total {
    0 -> 1.0
    _ -> {
      let raw_edits = myers.diff(a_chars, b_chars)
      let matching = count_matching_raw(raw_edits, 0)
      int.to_float(2 * matching) /. int.to_float(total)
    }
  }
}

fn count_matching_raw(edits: List(RawEdit), acc: Int) -> Int {
  case edits {
    [] -> acc
    [RawEqual(_), ..rest] -> count_matching_raw(rest, acc + 1)
    [_, ..rest] -> count_matching_raw(rest, acc)
  }
}
