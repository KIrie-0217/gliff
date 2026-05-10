import gleam/list
import gleam/string
import gliff/internal/myers
import gliff/types.{
  type Edit, type InlineEdit, type RawEdit, type Span, Changed, Delete, Equal,
  InlineDelete, InlineEqual, InlineInsert, Insert, RawDelete, RawEqual,
  RawInsert, Unchanged,
}

pub fn highlight(edits: List(Edit)) -> List(InlineEdit) {
  highlight_loop(edits, [])
  |> list.reverse
}

fn highlight_loop(edits: List(Edit), acc: List(InlineEdit)) -> List(InlineEdit) {
  case edits {
    [] -> acc
    [Equal(lines), ..rest] -> highlight_loop(rest, [InlineEqual(lines), ..acc])
    [Delete(del_lines), Insert(ins_lines), ..rest] -> {
      let del_spans = diff_line_pair(del_lines, ins_lines, True)
      let ins_spans = diff_line_pair(del_lines, ins_lines, False)
      highlight_loop(rest, [
        InlineInsert(ins_spans),
        InlineDelete(del_spans),
        ..acc
      ])
    }
    [Delete(lines), ..rest] -> {
      let spans = list.map(lines, fn(l) { Changed(l) })
      highlight_loop(rest, [InlineDelete(spans), ..acc])
    }
    [Insert(lines), ..rest] -> {
      let spans = list.map(lines, fn(l) { Changed(l) })
      highlight_loop(rest, [InlineInsert(spans), ..acc])
    }
  }
}

fn diff_line_pair(
  del_lines: List(String),
  ins_lines: List(String),
  for_delete: Bool,
) -> List(Span) {
  let del_text = string.join(del_lines, "\n")
  let ins_text = string.join(ins_lines, "\n")
  let del_chars = string.to_graphemes(del_text)
  let ins_chars = string.to_graphemes(ins_text)
  let raw_edits = myers.diff(del_chars, ins_chars)
  raw_edits_to_spans(raw_edits, for_delete)
}

fn raw_edits_to_spans(raw_edits: List(RawEdit), for_delete: Bool) -> List(Span) {
  collect_spans(raw_edits, for_delete, "", False, [])
  |> list.reverse
}

fn collect_spans(
  edits: List(RawEdit),
  for_delete: Bool,
  current: String,
  current_is_changed: Bool,
  acc: List(Span),
) -> List(Span) {
  case edits {
    [] ->
      case current {
        "" -> acc
        _ ->
          case current_is_changed {
            True -> [Changed(current), ..acc]
            False -> [Unchanged(current), ..acc]
          }
      }
    [edit, ..rest] -> {
      let #(char, is_changed) = classify_edit(edit, for_delete)
      case char {
        "" -> collect_spans(rest, for_delete, current, current_is_changed, acc)
        _ ->
          case is_changed == current_is_changed {
            True ->
              collect_spans(
                rest,
                for_delete,
                current <> char,
                current_is_changed,
                acc,
              )
            False -> {
              let new_acc = case current {
                "" -> acc
                _ ->
                  case current_is_changed {
                    True -> [Changed(current), ..acc]
                    False -> [Unchanged(current), ..acc]
                  }
              }
              collect_spans(rest, for_delete, char, is_changed, new_acc)
            }
          }
      }
    }
  }
}

fn classify_edit(edit: RawEdit, for_delete: Bool) -> #(String, Bool) {
  case edit {
    RawEqual(v) -> #(v, False)
    RawDelete(v) ->
      case for_delete {
        True -> #(v, True)
        False -> #("", False)
      }
    RawInsert(v) ->
      case for_delete {
        True -> #("", False)
        False -> #(v, True)
      }
  }
}
