import gleam/list
import gleam/string
import gliff/types.{type Edit, type Hunk, Delete, Equal, Hunk, Insert}

pub fn to_unified(
  edits: List(Edit),
  old_name old_name: String,
  new_name new_name: String,
) -> String {
  let hunks = edits_to_hunks(edits, 3)
  let header = "--- " <> old_name <> "\n+++ " <> new_name <> "\n"
  let body = string.join(list.map(hunks, format_hunk), "")
  header <> body
}

pub fn from_unified(unified: String) -> Result(List(Hunk), String) {
  parse_unified(unified)
}

// --- Hunk construction ---

fn edits_to_hunks(edits: List(Edit), context: Int) -> List(Hunk) {
  let indexed = index_edits(edits, 0, 0, [])
  build_hunks(indexed, context)
}

type IndexedEdit {
  IndexedEdit(edit: Edit, old_start: Int, new_start: Int)
}

fn index_edits(
  edits: List(Edit),
  old_pos: Int,
  new_pos: Int,
  acc: List(IndexedEdit),
) -> List(IndexedEdit) {
  case edits {
    [] -> list.reverse(acc)
    [edit, ..rest] -> {
      let entry = IndexedEdit(edit:, old_start: old_pos, new_start: new_pos)
      let #(old_advance, new_advance) = edit_size(edit)
      index_edits(rest, old_pos + old_advance, new_pos + new_advance, [
        entry,
        ..acc
      ])
    }
  }
}

fn edit_size(edit: Edit) -> #(Int, Int) {
  case edit {
    Equal(lines) -> {
      let n = list.length(lines)
      #(n, n)
    }
    Delete(lines) -> #(list.length(lines), 0)
    Insert(lines) -> #(0, list.length(lines))
  }
}

fn build_hunks(indexed: List(IndexedEdit), context: Int) -> List(Hunk) {
  let change_groups = find_change_groups(indexed, context)
  list.map(change_groups, fn(group) { build_single_hunk(group) })
}

fn find_change_groups(
  indexed: List(IndexedEdit),
  context: Int,
) -> List(List(IndexedEdit)) {
  find_change_groups_loop(indexed, context, [], [])
}

fn find_change_groups_loop(
  indexed: List(IndexedEdit),
  context: Int,
  current_group: List(IndexedEdit),
  groups: List(List(IndexedEdit)),
) -> List(List(IndexedEdit)) {
  case indexed {
    [] ->
      case current_group {
        [] -> list.reverse(groups)
        _ -> list.reverse([list.reverse(current_group), ..groups])
      }
    [entry, ..rest] ->
      case entry.edit {
        Equal(lines) -> {
          let n = list.length(lines)
          case current_group {
            [] -> {
              let ctx_lines = take_last(lines, context)
              let ctx_count = list.length(ctx_lines)
              case ctx_count > 0 {
                True -> {
                  let ctx_entry =
                    IndexedEdit(
                      edit: Equal(ctx_lines),
                      old_start: entry.old_start + n - ctx_count,
                      new_start: entry.new_start + n - ctx_count,
                    )
                  find_change_groups_loop(rest, context, [ctx_entry], groups)
                }
                False ->
                  find_change_groups_loop(rest, context, current_group, groups)
              }
            }
            _ -> {
              let has_more_changes = has_changes(rest)
              case has_more_changes, n > context * 2 {
                _, True -> {
                  let tail_ctx = list.take(lines, context)
                  let tail_entry =
                    IndexedEdit(
                      edit: Equal(tail_ctx),
                      old_start: entry.old_start,
                      new_start: entry.new_start,
                    )
                  let finished_group =
                    list.reverse([tail_entry, ..current_group])

                  let head_ctx = take_last(lines, context)
                  let head_count = list.length(head_ctx)
                  let head_entry =
                    IndexedEdit(
                      edit: Equal(head_ctx),
                      old_start: entry.old_start + n - head_count,
                      new_start: entry.new_start + n - head_count,
                    )
                  find_change_groups_loop(rest, context, [head_entry], [
                    finished_group,
                    ..groups
                  ])
                }
                False, _ if n > context -> {
                  let tail_ctx = list.take(lines, context)
                  let tail_entry =
                    IndexedEdit(
                      edit: Equal(tail_ctx),
                      old_start: entry.old_start,
                      new_start: entry.new_start,
                    )
                  let finished_group =
                    list.reverse([tail_entry, ..current_group])
                  find_change_groups_loop(rest, context, [], [
                    finished_group,
                    ..groups
                  ])
                }
                _, _ ->
                  find_change_groups_loop(
                    rest,
                    context,
                    [entry, ..current_group],
                    groups,
                  )
              }
            }
          }
        }
        _ -> {
          case current_group {
            [] -> find_change_groups_loop(rest, context, [entry], groups)
            _ ->
              find_change_groups_loop(
                rest,
                context,
                [entry, ..current_group],
                groups,
              )
          }
        }
      }
  }
}

fn has_changes(indexed: List(IndexedEdit)) -> Bool {
  case indexed {
    [] -> False
    [entry, ..rest] ->
      case entry.edit {
        Equal(_) -> has_changes(rest)
        _ -> True
      }
  }
}

fn build_single_hunk(entries: List(IndexedEdit)) -> Hunk {
  case entries {
    [] ->
      Hunk(old_start: 1, old_count: 0, new_start: 1, new_count: 0, edits: [])
    [first, ..] -> {
      let edits = list.map(entries, fn(e) { e.edit })
      let old_start = first.old_start + 1
      let new_start = first.new_start + 1
      let #(old_count, new_count) = count_lines_in_edits(edits, 0, 0)
      Hunk(old_start:, old_count:, new_start:, new_count:, edits:)
    }
  }
}

fn count_lines_in_edits(
  edits: List(Edit),
  old_acc: Int,
  new_acc: Int,
) -> #(Int, Int) {
  case edits {
    [] -> #(old_acc, new_acc)
    [edit, ..rest] -> {
      let #(o, n) = edit_size(edit)
      count_lines_in_edits(rest, old_acc + o, new_acc + n)
    }
  }
}

// --- Formatting ---

fn format_hunk(hunk: Hunk) -> String {
  let header =
    "@@ -"
    <> int_to_string(hunk.old_start)
    <> ","
    <> int_to_string(hunk.old_count)
    <> " +"
    <> int_to_string(hunk.new_start)
    <> ","
    <> int_to_string(hunk.new_count)
    <> " @@\n"
  let body = string.join(list.map(hunk.edits, format_edit), "")
  header <> body
}

fn format_edit(edit: Edit) -> String {
  case edit {
    Equal(lines) -> string.join(list.map(lines, fn(l) { " " <> l <> "\n" }), "")
    Delete(lines) ->
      string.join(list.map(lines, fn(l) { "-" <> l <> "\n" }), "")
    Insert(lines) ->
      string.join(list.map(lines, fn(l) { "+" <> l <> "\n" }), "")
  }
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

fn take_last(items: List(a), n: Int) -> List(a) {
  let len = list.length(items)
  list.drop(items, case len > n {
    True -> len - n
    False -> 0
  })
}

// --- Parsing ---

fn parse_unified(input: String) -> Result(List(Hunk), String) {
  let lines = string.split(input, "\n")
  let content_lines = skip_file_headers(lines)
  parse_hunks(content_lines, [])
}

fn skip_file_headers(lines: List(String)) -> List(String) {
  case lines {
    ["---" <> _, "+++ " <> _, ..rest] -> rest
    [_, ..rest] -> skip_file_headers(rest)
    [] -> []
  }
}

fn parse_hunks(
  lines: List(String),
  acc: List(Hunk),
) -> Result(List(Hunk), String) {
  case lines {
    [] -> Ok(list.reverse(acc))
    ["", ..rest] -> parse_hunks(rest, acc)
    ["@@" <> _ as header, ..rest] ->
      case parse_hunk_header(header) {
        Ok(#(old_start, old_count, new_start, new_count)) -> {
          let #(edits, remaining) = parse_hunk_body(rest, [])
          let hunk =
            Hunk(old_start:, old_count:, new_start:, new_count:, edits:)
          parse_hunks(remaining, [hunk, ..acc])
        }
        Error(e) -> Error(e)
      }
    [line, ..] -> Error("Unexpected line: " <> line)
  }
}

fn parse_hunk_header(header: String) -> Result(#(Int, Int, Int, Int), String) {
  case string.split(header, "@@") {
    [_, range_str, ..] -> parse_ranges(string.trim(range_str))
    _ -> Error("Invalid hunk header: " <> header)
  }
}

fn parse_ranges(range_str: String) -> Result(#(Int, Int, Int, Int), String) {
  case string.split(range_str, " ") {
    [old_range, new_range, ..] -> {
      case
        parse_range(string.drop_start(old_range, 1)),
        parse_range(string.drop_start(new_range, 1))
      {
        Ok(#(os, oc)), Ok(#(ns, nc)) -> Ok(#(os, oc, ns, nc))
        _, _ -> Error("Invalid range: " <> range_str)
      }
    }
    _ -> Error("Invalid range format: " <> range_str)
  }
}

fn parse_range(range: String) -> Result(#(Int, Int), String) {
  case string.split(range, ",") {
    [start_str, count_str] ->
      case parse_int(start_str), parse_int(count_str) {
        Ok(s), Ok(c) -> Ok(#(s, c))
        _, _ -> Error("Invalid range numbers")
      }
    [start_str] ->
      case parse_int(start_str) {
        Ok(s) -> Ok(#(s, 1))
        Error(_) -> Error("Invalid range number")
      }
    _ -> Error("Invalid range")
  }
}

fn parse_int(s: String) -> Result(Int, String) {
  parse_int_loop(string.to_graphemes(s), 0, False)
}

fn parse_int_loop(
  chars: List(String),
  acc: Int,
  started: Bool,
) -> Result(Int, String) {
  case chars {
    [] ->
      case started {
        True -> Ok(acc)
        False -> Error("Empty integer")
      }
    ["-", ..rest] ->
      case started {
        False -> {
          case parse_int_loop(rest, 0, False) {
            Ok(n) -> Ok(-n)
            Error(e) -> Error(e)
          }
        }
        True -> Error("Unexpected '-'")
      }
    [d, ..rest] ->
      case digit_value(d) {
        Ok(v) -> parse_int_loop(rest, acc * 10 + v, True)
        Error(_) -> Error("Not a digit: " <> d)
      }
  }
}

fn digit_value(d: String) -> Result(Int, Nil) {
  case d {
    "0" -> Ok(0)
    "1" -> Ok(1)
    "2" -> Ok(2)
    "3" -> Ok(3)
    "4" -> Ok(4)
    "5" -> Ok(5)
    "6" -> Ok(6)
    "7" -> Ok(7)
    "8" -> Ok(8)
    "9" -> Ok(9)
    _ -> Error(Nil)
  }
}

fn parse_hunk_body(
  lines: List(String),
  acc: List(Edit),
) -> #(List(Edit), List(String)) {
  case lines {
    [] -> #(group_raw_body(list.reverse(acc)), [])
    ["@@" <> _ as rest_line, ..rest] -> #(group_raw_body(list.reverse(acc)), [
      rest_line,
      ..rest
    ])
    [line, ..rest] -> {
      let edit = case string.first(line) {
        Ok("+") -> Insert([string.drop_start(line, 1)])
        Ok("-") -> Delete([string.drop_start(line, 1)])
        Ok(" ") -> Equal([string.drop_start(line, 1)])
        _ -> Equal([line])
      }
      parse_hunk_body(rest, [edit, ..acc])
    }
  }
}

fn group_raw_body(edits: List(Edit)) -> List(Edit) {
  group_raw_body_loop(edits, [])
  |> list.reverse
}

fn group_raw_body_loop(edits: List(Edit), acc: List(Edit)) -> List(Edit) {
  case edits {
    [] -> acc
    [Equal(l1), Equal(l2), ..rest] ->
      group_raw_body_loop([Equal(list.append(l1, l2)), ..rest], acc)
    [Insert(l1), Insert(l2), ..rest] ->
      group_raw_body_loop([Insert(list.append(l1, l2)), ..rest], acc)
    [Delete(l1), Delete(l2), ..rest] ->
      group_raw_body_loop([Delete(list.append(l1, l2)), ..rest], acc)
    [edit, ..rest] -> group_raw_body_loop(rest, [edit, ..acc])
  }
}
