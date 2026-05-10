import gleam/int
import gleam/list
import gliff/types.{type Edit, Delete, Equal, Insert}

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
