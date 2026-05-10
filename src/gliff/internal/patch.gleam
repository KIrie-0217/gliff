import gleam/list
import gleam/string
import gliff/types.{type Edit, Delete, Equal, Insert}

pub fn apply_patch(text: String, edits: List(Edit)) -> Result(String, String) {
  let lines = split_lines(text)
  apply_edits(lines, edits, [])
}

fn split_lines(text: String) -> List(String) {
  case text {
    "" -> []
    _ -> string.split(text, "\n")
  }
}

fn apply_edits(
  lines: List(String),
  edits: List(Edit),
  acc: List(String),
) -> Result(String, String) {
  case edits {
    [] ->
      case lines {
        [] -> Ok(string.join(list.reverse(acc), "\n"))
        remaining ->
          Ok(string.join(list.append(list.reverse(acc), remaining), "\n"))
      }
    [edit, ..rest_edits] ->
      case edit {
        Equal(expected) -> {
          case consume_lines(lines, expected) {
            Ok(remaining) ->
              apply_edits(
                remaining,
                rest_edits,
                prepend_reversed(expected, acc),
              )
            Error(e) -> Error(e)
          }
        }
        Delete(expected) -> {
          case consume_lines(lines, expected) {
            Ok(remaining) -> apply_edits(remaining, rest_edits, acc)
            Error(e) -> Error(e)
          }
        }
        Insert(new_lines) ->
          apply_edits(lines, rest_edits, prepend_reversed(new_lines, acc))
      }
  }
}

fn consume_lines(
  lines: List(String),
  expected: List(String),
) -> Result(List(String), String) {
  case expected {
    [] -> Ok(lines)
    [exp, ..rest_exp] ->
      case lines {
        [] -> Error("Unexpected end of input, expected: " <> exp)
        [line, ..rest_lines] ->
          case line == exp {
            True -> consume_lines(rest_lines, rest_exp)
            False ->
              Error(
                "Mismatch: expected '" <> exp <> "' but got '" <> line <> "'",
              )
          }
      }
  }
}

fn prepend_reversed(items: List(a), onto: List(a)) -> List(a) {
  case items {
    [] -> onto
    [h, ..t] -> prepend_reversed(t, [h, ..onto])
  }
}
