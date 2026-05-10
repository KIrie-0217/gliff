import gleam/list
import gleam/string
import gliff/internal/inline
import gliff/internal/unified
import gliff/types.{
  type Edit, type Hunk, type InlineEdit, type Span, Changed, Delete, Equal,
  InlineDelete, InlineEqual, InlineInsert, Insert, Unchanged,
}

const red = "\u{001b}[31m"

const green = "\u{001b}[32m"

const cyan = "\u{001b}[36m"

const bold = "\u{001b}[1m"

const reset = "\u{001b}[0m"

pub fn to_ansi(
  edits: List(Edit),
  old_name old_name: String,
  new_name new_name: String,
) -> String {
  let hunks = unified.edits_to_hunks(edits, 3)
  let header =
    bold
    <> "--- "
    <> old_name
    <> reset
    <> "\n"
    <> bold
    <> "+++ "
    <> new_name
    <> reset
    <> "\n"
  let body = string.join(list.map(hunks, format_hunk_ansi), "")
  header <> body
}

pub fn to_ansi_inline(edits: List(Edit)) -> String {
  let inline_edits = inline.highlight(edits)
  string.join(list.map(inline_edits, format_inline_edit), "")
}

fn format_hunk_ansi(hunk: Hunk) -> String {
  let header =
    cyan
    <> "@@ -"
    <> int_to_string(hunk.old_start)
    <> ","
    <> int_to_string(hunk.old_count)
    <> " +"
    <> int_to_string(hunk.new_start)
    <> ","
    <> int_to_string(hunk.new_count)
    <> " @@"
    <> reset
    <> "\n"
  let body = string.join(list.map(hunk.edits, format_edit_ansi), "")
  header <> body
}

fn format_edit_ansi(edit: Edit) -> String {
  case edit {
    Equal(lines) -> string.join(list.map(lines, fn(l) { " " <> l <> "\n" }), "")
    Delete(lines) ->
      string.join(
        list.map(lines, fn(l) { red <> "-" <> l <> reset <> "\n" }),
        "",
      )
    Insert(lines) ->
      string.join(
        list.map(lines, fn(l) { green <> "+" <> l <> reset <> "\n" }),
        "",
      )
  }
}

fn format_inline_edit(edit: InlineEdit) -> String {
  case edit {
    InlineEqual(lines) ->
      string.join(list.map(lines, fn(l) { " " <> l <> "\n" }), "")
    InlineDelete(spans) ->
      red <> "-" <> format_spans(spans, red) <> reset <> "\n"
    InlineInsert(spans) ->
      green <> "+" <> format_spans(spans, green) <> reset <> "\n"
  }
}

fn format_spans(spans: List(Span), base_color: String) -> String {
  string.join(
    list.map(spans, fn(span) {
      case span {
        Unchanged(text) -> text
        Changed(text) -> bold <> text <> reset <> base_color
      }
    }),
    "",
  )
}

fn int_to_string(n: Int) -> String {
  case n < 0 {
    True -> "-" <> do_int_to_string(-n)
    False -> do_int_to_string(n)
  }
}

fn do_int_to_string(n: Int) -> String {
  case n < 10 {
    True -> digit_to_string(n)
    False -> do_int_to_string(n / 10) <> digit_to_string(n % 10)
  }
}

fn digit_to_string(d: Int) -> String {
  case d {
    0 -> "0"
    1 -> "1"
    2 -> "2"
    3 -> "3"
    4 -> "4"
    5 -> "5"
    6 -> "6"
    7 -> "7"
    8 -> "8"
    _ -> "9"
  }
}
