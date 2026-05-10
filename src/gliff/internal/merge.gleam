import gleam/list
import gleam/string
import gliff/internal/myers
import gliff/types.{
  type Conflict, type MergeResult, type RawEdit, Conflict, MergeConflict,
  MergeOk, RawDelete, RawEqual, RawInsert,
}

pub fn merge3(base: String, ours: String, theirs: String) -> MergeResult {
  let base_lines = split_lines(base)
  let ours_lines = split_lines(ours)
  let theirs_lines = split_lines(theirs)

  let ours_edits = myers.diff(base_lines, ours_lines)
  let theirs_edits = myers.diff(base_lines, theirs_lines)

  let ours_hunks = edits_to_change_hunks(ours_edits, 0, [])
  let theirs_hunks = edits_to_change_hunks(theirs_edits, 0, [])

  merge_hunks(base_lines, ours_hunks, theirs_hunks, 0, [], [])
}

type ChangeHunk {
  ChangeHunk(base_start: Int, base_end: Int, new_lines: List(String))
}

fn edits_to_change_hunks(
  edits: List(RawEdit),
  pos: Int,
  acc: List(ChangeHunk),
) -> List(ChangeHunk) {
  case edits {
    [] -> list.reverse(acc)
    [RawEqual(_), ..rest] -> edits_to_change_hunks(rest, pos + 1, acc)
    _ -> {
      let #(hunk, remaining, new_pos) = collect_change(edits, pos, [], [])
      edits_to_change_hunks(remaining, new_pos, [hunk, ..acc])
    }
  }
}

fn collect_change(
  edits: List(RawEdit),
  pos: Int,
  deleted: List(String),
  inserted: List(String),
) -> #(ChangeHunk, List(RawEdit), Int) {
  case edits {
    [RawDelete(v), ..rest] ->
      collect_change(rest, pos + 1, [v, ..deleted], inserted)
    [RawInsert(v), ..rest] ->
      collect_change(rest, pos, deleted, [v, ..inserted])
    _ -> {
      let base_start = pos - list.length(deleted)
      let hunk =
        ChangeHunk(
          base_start:,
          base_end: pos,
          new_lines: list.reverse(inserted),
        )
      #(hunk, edits, pos)
    }
  }
}

fn merge_hunks(
  base_lines: List(String),
  ours: List(ChangeHunk),
  theirs: List(ChangeHunk),
  pos: Int,
  output: List(String),
  conflicts: List(Conflict),
) -> MergeResult {
  case ours, theirs {
    [], [] -> {
      let remaining = list.drop(base_lines, pos)
      let final_output = list.append(list.reverse(output), remaining)
      let merged = string.join(final_output, "\n")
      case conflicts {
        [] -> MergeOk(merged:)
        _ -> MergeConflict(merged:, conflicts: list.reverse(conflicts))
      }
    }
    [o, ..rest_ours], [] -> {
      let context = slice_lines(base_lines, pos, o.base_start)
      let new_output =
        list.append(
          list.reverse(o.new_lines),
          list.append(list.reverse(context), output),
        )
      merge_hunks(base_lines, rest_ours, [], o.base_end, new_output, conflicts)
    }
    [], [t, ..rest_theirs] -> {
      let context = slice_lines(base_lines, pos, t.base_start)
      let new_output =
        list.append(
          list.reverse(t.new_lines),
          list.append(list.reverse(context), output),
        )
      merge_hunks(
        base_lines,
        [],
        rest_theirs,
        t.base_end,
        new_output,
        conflicts,
      )
    }
    [o, ..rest_ours], [t, ..rest_theirs] -> {
      case hunks_overlap(o, t) {
        False -> {
          case o.base_start <= t.base_start {
            True -> {
              let context = slice_lines(base_lines, pos, o.base_start)
              let new_output =
                list.append(
                  list.reverse(o.new_lines),
                  list.append(list.reverse(context), output),
                )
              merge_hunks(
                base_lines,
                rest_ours,
                [t, ..rest_theirs],
                o.base_end,
                new_output,
                conflicts,
              )
            }
            False -> {
              let context = slice_lines(base_lines, pos, t.base_start)
              let new_output =
                list.append(
                  list.reverse(t.new_lines),
                  list.append(list.reverse(context), output),
                )
              merge_hunks(
                base_lines,
                [o, ..rest_ours],
                rest_theirs,
                t.base_end,
                new_output,
                conflicts,
              )
            }
          }
        }
        True -> {
          case o.new_lines == t.new_lines {
            True -> {
              let context = slice_lines(base_lines, pos, o.base_start)
              let merged_end = max(o.base_end, t.base_end)
              let new_output =
                list.append(
                  list.reverse(o.new_lines),
                  list.append(list.reverse(context), output),
                )
              merge_hunks(
                base_lines,
                rest_ours,
                rest_theirs,
                merged_end,
                new_output,
                conflicts,
              )
            }
            False -> {
              let merged_start = min(o.base_start, t.base_start)
              let merged_end = max(o.base_end, t.base_end)
              let context = slice_lines(base_lines, pos, merged_start)
              let base_conflict_lines =
                slice_lines(base_lines, merged_start, merged_end)
              let conflict_markers = [
                ">>>>>>> theirs",
                ..list.append(list.reverse(t.new_lines), [
                  "=======",
                  ..list.append(list.reverse(o.new_lines), [
                    "<<<<<<< ours",
                  ])
                ])
              ]
              let new_output =
                list.append(
                  conflict_markers,
                  list.append(list.reverse(context), output),
                )
              let conflict =
                Conflict(
                  base_lines: base_conflict_lines,
                  our_lines: o.new_lines,
                  their_lines: t.new_lines,
                )
              merge_hunks(
                base_lines,
                rest_ours,
                rest_theirs,
                merged_end,
                new_output,
                [conflict, ..conflicts],
              )
            }
          }
        }
      }
    }
  }
}

fn hunks_overlap(a: ChangeHunk, b: ChangeHunk) -> Bool {
  a.base_start < b.base_end && b.base_start < a.base_end
}

fn slice_lines(lines: List(String), from: Int, to: Int) -> List(String) {
  lines
  |> list.drop(from)
  |> list.take(to - from)
}

fn split_lines(text: String) -> List(String) {
  case text {
    "" -> []
    _ -> string.split(text, "\n")
  }
}

fn max(a: Int, b: Int) -> Int {
  case a > b {
    True -> a
    False -> b
  }
}

fn min(a: Int, b: Int) -> Int {
  case a < b {
    True -> a
    False -> b
  }
}
