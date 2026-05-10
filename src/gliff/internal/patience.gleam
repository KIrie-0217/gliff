import gleam/dict.{type Dict}
import gleam/list
import gleam/order
import gliff/internal/myers
import gliff/types.{type RawEdit, RawDelete, RawEqual, RawInsert}

pub fn diff(old: List(String), new: List(String)) -> List(RawEdit) {
  case old, new {
    [], [] -> []
    [], _ -> list.map(new, RawInsert)
    _, [] -> list.map(old, RawDelete)
    _, _ -> {
      let old_unique = find_unique(old)
      let new_unique = find_unique(new)
      let matches = find_matches(old_unique, new_unique)

      case matches {
        [] -> myers.diff(old, new)
        _ -> {
          let lis = longest_increasing_subsequence(matches)
          diff_between_anchors(old, new, lis, 0, 0, [])
          |> list.reverse
        }
      }
    }
  }
}

type Match {
  Match(old_idx: Int, new_idx: Int, value: String)
}

fn find_unique(lines: List(String)) -> Dict(String, Int) {
  let counts = count_occurrences(lines, dict.new())
  let indexed = index_lines(lines, 0, dict.new())
  dict.fold(counts, dict.new(), fn(acc, key, count) {
    case count == 1 {
      True ->
        case dict.get(indexed, key) {
          Ok(idx) -> dict.insert(acc, key, idx)
          Error(_) -> acc
        }
      False -> acc
    }
  })
}

fn count_occurrences(
  lines: List(String),
  acc: Dict(String, Int),
) -> Dict(String, Int) {
  case lines {
    [] -> acc
    [line, ..rest] -> {
      let count = case dict.get(acc, line) {
        Ok(n) -> n + 1
        Error(_) -> 1
      }
      count_occurrences(rest, dict.insert(acc, line, count))
    }
  }
}

fn index_lines(
  lines: List(String),
  idx: Int,
  acc: Dict(String, Int),
) -> Dict(String, Int) {
  case lines {
    [] -> acc
    [line, ..rest] -> index_lines(rest, idx + 1, dict.insert(acc, line, idx))
  }
}

fn find_matches(
  old_unique: Dict(String, Int),
  new_unique: Dict(String, Int),
) -> List(Match) {
  dict.fold(old_unique, [], fn(acc, line, old_idx) {
    case dict.get(new_unique, line) {
      Ok(new_idx) -> [Match(old_idx:, new_idx:, value: line), ..acc]
      Error(_) -> acc
    }
  })
  |> list.sort(fn(a, b) { compare_int(a.old_idx, b.old_idx) })
}

fn longest_increasing_subsequence(matches: List(Match)) -> List(Match) {
  case matches {
    [] -> []
    [only] -> [only]
    _ -> lis_loop(matches, [])
  }
}

fn lis_loop(
  remaining: List(Match),
  tails: List(#(Int, List(Match))),
) -> List(Match) {
  case remaining {
    [] ->
      case list.last(tails) {
        Ok(#(_, seq)) -> list.reverse(seq)
        Error(_) -> []
      }
    [m, ..rest] -> {
      let new_tails = insert_into_tails(tails, m, [])
      lis_loop(rest, new_tails)
    }
  }
}

fn insert_into_tails(
  tails: List(#(Int, List(Match))),
  m: Match,
  acc: List(#(Int, List(Match))),
) -> List(#(Int, List(Match))) {
  case tails {
    [] -> list.reverse([#(m.new_idx, [m]), ..acc])
    [#(tail_val, seq), ..rest] -> {
      case m.new_idx <= tail_val {
        True -> {
          let new_seq = case acc {
            [] -> [m]
            [#(_, prev_seq), ..] -> [m, ..prev_seq]
          }
          list.append(list.reverse([#(m.new_idx, new_seq), ..acc]), rest)
        }
        False -> insert_into_tails(rest, m, [#(tail_val, seq), ..acc])
      }
    }
  }
}

fn diff_between_anchors(
  old: List(String),
  new: List(String),
  anchors: List(Match),
  old_pos: Int,
  new_pos: Int,
  acc: List(RawEdit),
) -> List(RawEdit) {
  case anchors {
    [] -> {
      let old_rest = list.drop(old, old_pos)
      let new_rest = list.drop(new, new_pos)
      let tail_edits = myers.diff(old_rest, new_rest)
      prepend_reversed(tail_edits, acc)
    }
    [Match(old_idx:, new_idx:, value:), ..rest_anchors] -> {
      let old_before = slice(old, old_pos, old_idx)
      let new_before = slice(new, new_pos, new_idx)
      let gap_edits = myers.diff(old_before, new_before)
      let acc1 = prepend_reversed(gap_edits, acc)
      let acc2 = [RawEqual(value), ..acc1]
      diff_between_anchors(
        old,
        new,
        rest_anchors,
        old_idx + 1,
        new_idx + 1,
        acc2,
      )
    }
  }
}

fn slice(items: List(a), from: Int, to: Int) -> List(a) {
  items
  |> list.drop(from)
  |> list.take(to - from)
}

fn prepend_reversed(items: List(a), onto: List(a)) -> List(a) {
  case items {
    [] -> onto
    [h, ..t] -> prepend_reversed(t, [h, ..onto])
  }
}

fn compare_int(a: Int, b: Int) -> order.Order {
  case a < b {
    True -> order.Lt
    False ->
      case a == b {
        True -> order.Eq
        False -> order.Gt
      }
  }
}
