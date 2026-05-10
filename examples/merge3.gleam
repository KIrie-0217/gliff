//// Output:
////
////   === Clean Merge ===
////   Status: OK
////   hello
////   gleam
////   world
////   updated
////
////   === Conflict ===
////   Status: Conflict (1 conflict)
////   hello
////   <<<<<<< ours
////   gleam
////   =======
////   rust
////   >>>>>>> theirs
////   world

import gleam/io
import gliff
import gliff/types.{MergeConflict, MergeOk}

pub fn main() {
  // Clean merge: ours changes line 2, theirs changes line 4
  io.println("=== Clean Merge ===")
  let base = "hello\nfoo\nworld\nbar"
  let ours = "hello\ngleam\nworld\nbar"
  let theirs = "hello\nfoo\nworld\nupdated"
  case gliff.merge3(base, ours, theirs) {
    MergeOk(merged:) -> {
      io.println("Status: OK")
      io.println(merged)
    }
    MergeConflict(merged:, ..) -> {
      io.println("Status: Conflict (unexpected)")
      io.println(merged)
    }
  }

  io.println("")

  // Conflict: both change line 2 differently
  io.println("=== Conflict ===")
  let base2 = "hello\nfoo\nworld"
  let ours2 = "hello\ngleam\nworld"
  let theirs2 = "hello\nrust\nworld"
  case gliff.merge3(base2, ours2, theirs2) {
    MergeOk(merged:) -> {
      io.println("Status: OK (unexpected)")
      io.println(merged)
    }
    MergeConflict(merged:, conflicts:) -> {
      let count = count_list(conflicts, 0)
      io.println("Status: Conflict (" <> int_to_str(count) <> " conflict)")
      io.println(merged)
    }
  }
}

fn count_list(items: List(a), acc: Int) -> Int {
  case items {
    [] -> acc
    [_, ..rest] -> count_list(rest, acc + 1)
  }
}

fn int_to_str(n: Int) -> String {
  case n {
    0 -> "0"
    1 -> "1"
    2 -> "2"
    3 -> "3"
    _ -> "many"
  }
}
