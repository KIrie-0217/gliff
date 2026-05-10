import gleam/dict.{type Dict}
import gleam/list
import gleam/result
import gliff/internal/budget.{type Budget, Unlimited}
import gliff/types.{type RawEdit, RawDelete, RawEqual, RawInsert}

pub fn diff(old: List(String), new: List(String)) -> List(RawEdit) {
  let #(edits, _) = diff_with_budget(old, new, Unlimited)
  edits
}

pub fn diff_with_budget(
  old: List(String),
  new: List(String),
  b: Budget,
) -> #(List(RawEdit), Bool) {
  let old_len = list.length(old)
  let new_len = list.length(new)

  case old_len, new_len {
    0, 0 -> #([], True)
    0, _ -> #(list.map(new, RawInsert), True)
    _, 0 -> #(list.map(old, RawDelete), True)
    _, _ -> {
      let #(prefix, old_mid, new_mid, suffix) =
        trim_common(old, new, old_len, new_len)
      let #(mid_edits, complete) = compute_diff(old_mid, new_mid, b)
      #(list.flatten([prefix, mid_edits, suffix]), complete)
    }
  }
}

fn trim_common(
  old: List(String),
  new: List(String),
  old_len: Int,
  new_len: Int,
) -> #(List(RawEdit), List(String), List(String), List(RawEdit)) {
  let prefix = common_prefix(old, new, [])
  let prefix_len = list.length(prefix)

  let old_rest = list.drop(old, prefix_len)
  let new_rest = list.drop(new, prefix_len)

  let old_rest_len = old_len - prefix_len
  let new_rest_len = new_len - prefix_len

  let suffix = common_suffix(old_rest, new_rest, old_rest_len, new_rest_len)
  let suffix_len = list.length(suffix)

  let old_mid = list.take(old_rest, old_rest_len - suffix_len)
  let new_mid = list.take(new_rest, new_rest_len - suffix_len)

  let prefix_edits = list.map(prefix, RawEqual)
  let suffix_edits = list.map(suffix, RawEqual)

  #(prefix_edits, old_mid, new_mid, suffix_edits)
}

fn common_prefix(
  a: List(String),
  b: List(String),
  acc: List(String),
) -> List(String) {
  case a, b {
    [ah, ..at], [bh, ..bt] if ah == bh -> common_prefix(at, bt, [ah, ..acc])
    _, _ -> list.reverse(acc)
  }
}

fn common_suffix(
  a: List(String),
  b: List(String),
  a_len: Int,
  b_len: Int,
) -> List(String) {
  let min_len = case a_len < b_len {
    True -> a_len
    False -> b_len
  }
  let a_rev = list.reverse(a)
  let b_rev = list.reverse(b)
  common_suffix_loop(a_rev, b_rev, min_len, [])
}

fn common_suffix_loop(
  a_rev: List(String),
  b_rev: List(String),
  remaining: Int,
  acc: List(String),
) -> List(String) {
  case remaining, a_rev, b_rev {
    0, _, _ -> acc
    _, [ah, ..at], [bh, ..bt] if ah == bh ->
      common_suffix_loop(at, bt, remaining - 1, [ah, ..acc])
    _, _, _ -> acc
  }
}

fn compute_diff(
  old: List(String),
  new: List(String),
  b: Budget,
) -> #(List(RawEdit), Bool) {
  let old_len = list.length(old)
  let new_len = list.length(new)

  case old_len, new_len {
    0, 0 -> #([], True)
    0, _ -> #(list.map(new, RawInsert), True)
    _, 0 -> #(list.map(old, RawDelete), True)
    _, _ -> myers_shortest_edit(old, new, old_len, new_len, b)
  }
}

fn myers_shortest_edit(
  old: List(String),
  new: List(String),
  old_len: Int,
  new_len: Int,
  b: Budget,
) -> #(List(RawEdit), Bool) {
  let max_d = old_len + new_len
  let old_arr = list_to_dict(old, 0)
  let new_arr = list_to_dict(new, 0)
  let v_init = dict.from_list([#(1, 0)])

  case find_path(old_arr, new_arr, old_len, new_len, max_d, 0, v_init, [], b) {
    Ok(trace) -> #(backtrack(trace, old_arr, new_arr, old_len, new_len), True)
    Error(Exhausted) -> #(
      list.append(list.map(old, RawDelete), list.map(new, RawInsert)),
      False,
    )
    Error(BudgetExceeded) -> #(
      list.append(list.map(old, RawDelete), list.map(new, RawInsert)),
      False,
    )
  }
}

type FindPathError {
  Exhausted
  BudgetExceeded
}

fn find_path(
  old_arr: Dict(Int, String),
  new_arr: Dict(Int, String),
  old_len: Int,
  new_len: Int,
  max_d: Int,
  d: Int,
  v: Dict(Int, Int),
  trace: List(Dict(Int, Int)),
  b: Budget,
) -> Result(List(Dict(Int, Int)), FindPathError) {
  case d > max_d {
    True -> Error(Exhausted)
    False -> {
      case budget.tick(b) {
        Error(_) -> Error(BudgetExceeded)
        Ok(new_b) -> {
          case explore_diagonals(old_arr, new_arr, old_len, new_len, d, -d, v) {
            Ok(#(new_v, True)) -> Ok(list.reverse([new_v, ..trace]))
            Ok(#(new_v, False)) ->
              find_path(
                old_arr,
                new_arr,
                old_len,
                new_len,
                max_d,
                d + 1,
                new_v,
                [new_v, ..trace],
                new_b,
              )
            Error(_) -> Error(Exhausted)
          }
        }
      }
    }
  }
}

fn explore_diagonals(
  old_arr: Dict(Int, String),
  new_arr: Dict(Int, String),
  old_len: Int,
  new_len: Int,
  d: Int,
  k: Int,
  v: Dict(Int, Int),
) -> Result(#(Dict(Int, Int), Bool), Nil) {
  case k > d {
    True -> Ok(#(v, False))
    False -> {
      let x = case k == -d {
        True -> get_v(v, k + 1)
        False ->
          case k == d {
            True -> get_v(v, k - 1) + 1
            False -> {
              let vkm1 = get_v(v, k - 1)
              let vkp1 = get_v(v, k + 1)
              case vkm1 < vkp1 {
                True -> vkp1
                False -> vkm1 + 1
              }
            }
          }
      }
      let y = x - k
      let #(final_x, final_y) =
        follow_diagonal(old_arr, new_arr, old_len, new_len, x, y)
      let new_v = dict.insert(v, k, final_x)
      case final_x >= old_len && final_y >= new_len {
        True -> Ok(#(new_v, True))
        False ->
          explore_diagonals(old_arr, new_arr, old_len, new_len, d, k + 2, new_v)
      }
    }
  }
}

fn follow_diagonal(
  old_arr: Dict(Int, String),
  new_arr: Dict(Int, String),
  old_len: Int,
  new_len: Int,
  x: Int,
  y: Int,
) -> #(Int, Int) {
  case x < old_len && y < new_len {
    True ->
      case dict.get(old_arr, x), dict.get(new_arr, y) {
        Ok(ov), Ok(nv) if ov == nv ->
          follow_diagonal(old_arr, new_arr, old_len, new_len, x + 1, y + 1)
        _, _ -> #(x, y)
      }
    False -> #(x, y)
  }
}

fn backtrack(
  trace: List(Dict(Int, Int)),
  old_arr: Dict(Int, String),
  new_arr: Dict(Int, String),
  old_len: Int,
  new_len: Int,
) -> List(RawEdit) {
  let trace_len = list.length(trace)
  let max_d = trace_len - 1
  backtrack_from(trace, old_arr, new_arr, max_d, old_len, new_len, [])
}

fn backtrack_from(
  trace: List(Dict(Int, Int)),
  old_arr: Dict(Int, String),
  new_arr: Dict(Int, String),
  d: Int,
  x: Int,
  y: Int,
  acc: List(RawEdit),
) -> List(RawEdit) {
  case d < 0 {
    True -> acc
    False -> {
      let k = x - y
      let end_x = x

      case d == 0 {
        True -> {
          emit_equals(old_arr, 0, end_x, acc)
        }
        False -> {
          let prev_v = get_trace_at(trace, d - 1)
          let prev_k = find_prev_k(prev_v, k, d)
          let prev_x = get_v(prev_v, prev_k)
          let prev_y = prev_x - prev_k

          let mid_x = case prev_k == k - 1 {
            True -> prev_x + 1
            False -> prev_x
          }

          let acc1 = emit_equals(old_arr, mid_x, end_x, acc)

          let acc2 = case prev_k == k - 1 {
            True ->
              case dict.get(old_arr, prev_x) {
                Ok(val) -> [RawDelete(val), ..acc1]
                Error(_) -> acc1
              }
            False ->
              case dict.get(new_arr, prev_y) {
                Ok(val) -> [RawInsert(val), ..acc1]
                Error(_) -> acc1
              }
          }

          backtrack_from(trace, old_arr, new_arr, d - 1, prev_x, prev_y, acc2)
        }
      }
    }
  }
}

fn find_prev_k(prev_v: Dict(Int, Int), k: Int, d: Int) -> Int {
  case k == -d {
    True -> k + 1
    False ->
      case k == d {
        True -> k - 1
        False -> {
          let vkm1 = get_v(prev_v, k - 1)
          let vkp1 = get_v(prev_v, k + 1)
          case vkm1 < vkp1 {
            True -> k + 1
            False -> k - 1
          }
        }
      }
  }
}

fn emit_equals(
  old_arr: Dict(Int, String),
  from: Int,
  to: Int,
  acc: List(RawEdit),
) -> List(RawEdit) {
  case from >= to {
    True -> acc
    False -> {
      let last_idx = to - 1
      case dict.get(old_arr, last_idx) {
        Ok(val) -> emit_equals(old_arr, from, last_idx, [RawEqual(val), ..acc])
        Error(_) -> acc
      }
    }
  }
}

fn get_trace_at(trace: List(Dict(Int, Int)), idx: Int) -> Dict(Int, Int) {
  case list.drop(trace, idx) {
    [v, ..] -> v
    [] -> dict.new()
  }
}

fn get_v(v: Dict(Int, Int), k: Int) -> Int {
  result.unwrap(dict.get(v, k), 0)
}

fn list_to_dict(items: List(String), idx: Int) -> Dict(Int, String) {
  case items {
    [] -> dict.new()
    [h, ..t] -> dict.insert(list_to_dict(t, idx + 1), idx, h)
  }
}
