import gleam/list
import gleam/string
import gliff/internal/similarity
import gliff/types.{type Edit, Delete, Equal, Insert}

pub fn apply_patch_fuzzy(
  text: String,
  edits: List(Edit),
  tolerance tolerance: Float,
) -> Result(String, String) {
  let lines = split_lines(text)
  let threshold = 1.0 -. tolerance
  apply_edits_fuzzy(lines, edits, threshold, [])
}

fn apply_edits_fuzzy(
  lines: List(String),
  edits: List(Edit),
  threshold: Float,
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
        Equal(expected) ->
          case consume_fuzzy(lines, expected, threshold) {
            Ok(remaining) ->
              apply_edits_fuzzy(
                remaining,
                rest_edits,
                threshold,
                prepend_reversed(expected, acc),
              )
            Error(e) -> Error(e)
          }
        Delete(expected) ->
          case consume_fuzzy(lines, expected, threshold) {
            Ok(remaining) ->
              apply_edits_fuzzy(remaining, rest_edits, threshold, acc)
            Error(e) -> Error(e)
          }
        Insert(new_lines) ->
          apply_edits_fuzzy(
            lines,
            rest_edits,
            threshold,
            prepend_reversed(new_lines, acc),
          )
      }
  }
}

fn consume_fuzzy(
  lines: List(String),
  expected: List(String),
  threshold: Float,
) -> Result(List(String), String) {
  case expected {
    [] -> Ok(lines)
    [exp, ..rest_exp] ->
      case lines {
        [] -> Error("Unexpected end of input, expected: " <> exp)
        [line, ..rest_lines] ->
          case line == exp {
            True -> consume_fuzzy(rest_lines, rest_exp, threshold)
            False -> {
              let sim = similarity.line_similarity(exp, line)
              case sim >=. threshold {
                True -> consume_fuzzy(rest_lines, rest_exp, threshold)
                False ->
                  Error(
                    "Fuzzy mismatch: expected '"
                    <> exp
                    <> "' but got '"
                    <> line
                    <> "'",
                  )
              }
            }
          }
      }
  }
}

fn split_lines(text: String) -> List(String) {
  case text {
    "" -> []
    _ -> string.split(text, "\n")
  }
}

fn prepend_reversed(items: List(a), onto: List(a)) -> List(a) {
  case items {
    [] -> onto
    [h, ..t] -> prepend_reversed(t, [h, ..onto])
  }
}
