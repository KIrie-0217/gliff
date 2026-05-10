import gleam/list
import gleam/string
import gliff/types.{type Edit, Delete, Equal, Insert}

pub fn semantic(edits: List(Edit)) -> List(Edit) {
  edits
  |> eliminate_trivial_equalities
  |> merge_adjacent
}

pub fn semantic_lossless(edits: List(Edit)) -> List(Edit) {
  shift_edits_to_boundaries(edits, [])
  |> list.reverse
  |> merge_adjacent
}

// --- Semantic cleanup: eliminate trivial equalities ---

fn eliminate_trivial_equalities(edits: List(Edit)) -> List(Edit) {
  eliminate_loop(edits, [])
  |> list.reverse
}

fn eliminate_loop(edits: List(Edit), acc: List(Edit)) -> List(Edit) {
  case edits {
    [] -> acc
    [Delete(d), Equal(eq), Insert(i), ..rest] -> {
      let eq_len = count_chars(eq)
      let d_len = count_chars(d)
      let i_len = count_chars(i)
      case eq_len * 2 < d_len || eq_len * 2 < i_len {
        True ->
          eliminate_loop(rest, [
            Insert(list.flatten([eq, i])),
            Delete(list.flatten([d, eq])),
            ..acc
          ])
        False ->
          eliminate_loop([Equal(eq), Insert(i), ..rest], [Delete(d), ..acc])
      }
    }
    [Insert(i), Equal(eq), Delete(d), ..rest] -> {
      let eq_len = count_chars(eq)
      let d_len = count_chars(d)
      let i_len = count_chars(i)
      case eq_len * 2 < d_len || eq_len * 2 < i_len {
        True ->
          eliminate_loop(rest, [
            Delete(list.flatten([eq, d])),
            Insert(list.flatten([i, eq])),
            ..acc
          ])
        False ->
          eliminate_loop([Equal(eq), Delete(d), ..rest], [Insert(i), ..acc])
      }
    }
    [edit, ..rest] -> eliminate_loop(rest, [edit, ..acc])
  }
}

// --- Semantic lossless: shift edits to natural boundaries ---

fn shift_edits_to_boundaries(edits: List(Edit), acc: List(Edit)) -> List(Edit) {
  case edits {
    [] -> acc
    [Equal(eq1), Delete(d), Equal(eq2), ..rest] -> {
      let #(new_eq1, new_d, new_eq2) = find_best_shift(eq1, d, eq2)
      case new_eq1 {
        [] ->
          shift_edits_to_boundaries([Equal(new_eq2), ..rest], [
            Delete(new_d),
            ..acc
          ])
        _ ->
          shift_edits_to_boundaries([Equal(new_eq2), ..rest], [
            Delete(new_d),
            Equal(new_eq1),
            ..acc
          ])
      }
    }
    [Equal(eq1), Insert(i), Equal(eq2), ..rest] -> {
      let #(new_eq1, new_i, new_eq2) = find_best_shift(eq1, i, eq2)
      case new_eq1 {
        [] ->
          shift_edits_to_boundaries([Equal(new_eq2), ..rest], [
            Insert(new_i),
            ..acc
          ])
        _ ->
          shift_edits_to_boundaries([Equal(new_eq2), ..rest], [
            Insert(new_i),
            Equal(new_eq1),
            ..acc
          ])
      }
    }
    [Equal(eq1), Delete(d), Insert(i), Equal(eq2), ..rest] -> {
      let #(new_eq1, new_d, _mid_eq) = find_best_shift(eq1, d, eq2)
      let #(_, new_i, new_eq2) = find_best_shift(eq1, i, eq2)
      case new_eq1 {
        [] ->
          shift_edits_to_boundaries([Equal(new_eq2), ..rest], [
            Insert(new_i),
            Delete(new_d),
            ..acc
          ])
        _ ->
          shift_edits_to_boundaries([Equal(new_eq2), ..rest], [
            Insert(new_i),
            Delete(new_d),
            Equal(new_eq1),
            ..acc
          ])
      }
    }
    [edit, ..rest] -> shift_edits_to_boundaries(rest, [edit, ..acc])
  }
}

fn find_best_shift(
  before: List(String),
  edit: List(String),
  after: List(String),
) -> #(List(String), List(String), List(String)) {
  let suffix_common = common_suffix_strings(edit, after)
  let prefix_common = common_prefix_strings(edit, before |> list.reverse)

  let suffix_len = list.length(suffix_common)
  let prefix_len = list.length(prefix_common)

  case
    suffix_len > 0
    && score_boundary(suffix_common, after) > score_boundary(edit, after)
  {
    True -> {
      let shifted_edit =
        list.append(
          take_last(before, suffix_len),
          list.take(edit, list.length(edit) - suffix_len),
        )
      let new_before = list.take(before, list.length(before) - suffix_len)
      let new_after = list.append(list.take(edit, suffix_len), after)
      #(new_before, shifted_edit, new_after)
    }
    False ->
      case
        prefix_len > 0
        && score_boundary_left(prefix_common, before)
        > score_boundary_left(edit, before)
      {
        True -> {
          let shifted_edit =
            list.append(
              list.drop(edit, prefix_len),
              take_last(before, prefix_len),
            )
          let new_before = list.append(before, list.take(edit, prefix_len))
          #(new_before, shifted_edit, after)
        }
        False -> #(before, edit, after)
      }
  }
}

fn score_boundary(edit_end: List(String), after: List(String)) -> Int {
  let last_of_edit = list.last(edit_end)
  let first_of_after = list.first(after)
  score_pair(last_of_edit, first_of_after)
}

fn score_boundary_left(edit_start: List(String), before: List(String)) -> Int {
  let last_of_before = list.last(before)
  let first_of_edit = list.first(edit_start)
  score_pair(last_of_before, first_of_edit)
}

fn score_pair(left: Result(String, Nil), right: Result(String, Nil)) -> Int {
  case left, right {
    Ok(l), Ok(r) -> score_between(l, r)
    _, _ -> 5
  }
}

fn score_between(left: String, right: String) -> Int {
  let l_end = string.last(left)
  let r_start = string.first(right)
  case l_end, r_start {
    Ok(lc), Ok(rc) -> {
      let l_blank = is_blank_line(left)
      let r_blank = is_blank_line(right)
      case l_blank && r_blank {
        True -> 6
        False ->
          case l_blank || r_blank {
            True -> 5
            False ->
              case lc == "\n" || rc == "\n" {
                True -> 5
                False ->
                  case is_sentence_end(lc) && rc == " " {
                    True -> 4
                    False ->
                      case is_whitespace(lc) || is_whitespace(rc) {
                        True -> 3
                        False ->
                          case is_non_alnum(lc) || is_non_alnum(rc) {
                            True -> 2
                            False -> 1
                          }
                      }
                  }
              }
          }
      }
    }
    _, _ -> 5
  }
}

fn is_blank_line(s: String) -> Bool {
  string.trim(s) == ""
}

fn is_sentence_end(c: String) -> Bool {
  c == "." || c == "!" || c == "?"
}

fn is_whitespace(c: String) -> Bool {
  c == " " || c == "\t" || c == "\n" || c == "\r"
}

fn is_non_alnum(c: String) -> Bool {
  case c {
    " " | "\t" | "\n" | "\r" -> False
    _ -> !is_alpha_or_digit(c)
  }
}

fn is_alpha_or_digit(c: String) -> Bool {
  string.contains(
    does: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789",
    contain: c,
  )
}

// --- Merge adjacent same-type edits ---

fn merge_adjacent(edits: List(Edit)) -> List(Edit) {
  merge_loop(edits, [])
  |> list.reverse
}

fn merge_loop(edits: List(Edit), acc: List(Edit)) -> List(Edit) {
  case edits {
    [] -> acc
    [Equal(l1), Equal(l2), ..rest] ->
      merge_loop([Equal(list.append(l1, l2)), ..rest], acc)
    [Insert(l1), Insert(l2), ..rest] ->
      merge_loop([Insert(list.append(l1, l2)), ..rest], acc)
    [Delete(l1), Delete(l2), ..rest] ->
      merge_loop([Delete(list.append(l1, l2)), ..rest], acc)
    [edit, ..rest] -> merge_loop(rest, [edit, ..acc])
  }
}

// --- Helpers ---

fn count_chars(lines: List(String)) -> Int {
  list.fold(lines, 0, fn(acc, line) { acc + string.length(line) })
}

fn common_suffix_strings(a: List(String), b: List(String)) -> List(String) {
  let a_rev = list.reverse(a)
  let b_start = b
  common_prefix_strings_inner(a_rev, b_start, [])
  |> list.reverse
}

fn common_prefix_strings(a: List(String), b: List(String)) -> List(String) {
  common_prefix_strings_inner(a, b, [])
  |> list.reverse
}

fn common_prefix_strings_inner(
  a: List(String),
  b: List(String),
  acc: List(String),
) -> List(String) {
  case a, b {
    [ah, ..at], [bh, ..bt] if ah == bh ->
      common_prefix_strings_inner(at, bt, [ah, ..acc])
    _, _ -> acc
  }
}

fn take_last(items: List(a), n: Int) -> List(a) {
  let len = list.length(items)
  list.drop(items, case len > n {
    True -> len - n
    False -> 0
  })
}
