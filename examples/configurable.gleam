//// Output:
////
////   === Default Config ===
////   Status: Complete
////   --- old
////   +++ new
////   @@ -1,10 +1,10 @@
////    one
////    two
////   -three
////   +THREE
////    four
////    five
////   -six
////   +SIX
////    seven
////    eight
////    nine
////   -ten
////   +TEN
////
////   === Patience + Semantic Cleanup ===
////   Status: Complete
////   --- old
////   +++ new
////   @@ -1,10 +1,10 @@
////    one
////    two
////   -three
////   +THREE
////    four
////    five
////   -six
////   +SIX
////    seven
////    eight
////    nine
////   -ten
////   +TEN
////
////   === Limited Budget (max_iterations: 2) ===
////   Status: Truncated (budget exceeded)
////   --- old
////   +++ new
////   @@ -1,8 +1,8 @@
////   -a
////   -b
////   -c
////   -d
////   -e
////   -f
////   -g
////   -h
////   +z
////   +y
////   +x
////   +w
////   +v
////   +u
////   +t
////   +s

import gleam/io
import gliff
import gliff/types.{
  type DiffResult, Complete, DiffConfig, Myers, NoCleanup, Patience,
  SemanticCleanup, Truncated,
}

pub fn main() {
  let old = "one\ntwo\nthree\nfour\nfive\nsix\nseven\neight\nnine\nten"
  let new = "one\ntwo\nTHREE\nfour\nfive\nSIX\nseven\neight\nnine\nTEN"

  // Default config: Myers, no cleanup, unlimited budget
  io.println("=== Default Config ===")
  let result = gliff.diff_with(old, new, gliff.default_config())
  print_result(result)

  // Patience with semantic cleanup
  io.println("\n=== Patience + Semantic Cleanup ===")
  let config =
    DiffConfig(algorithm: Patience, cleanup: SemanticCleanup, max_iterations: 0)
  let result = gliff.diff_with(old, new, config)
  print_result(result)

  // Limited budget (will truncate on very different inputs)
  io.println("\n=== Limited Budget (max_iterations: 2) ===")
  let hard_old = "a\nb\nc\nd\ne\nf\ng\nh"
  let hard_new = "z\ny\nx\nw\nv\nu\nt\ns"
  let config = DiffConfig(algorithm: Myers, cleanup: NoCleanup, max_iterations: 2)
  let result = gliff.diff_with(hard_old, hard_new, config)
  print_result(result)
}

fn print_result(result: DiffResult) -> Nil {
  case result {
    Complete(edits:) -> {
      io.println("Status: Complete")
      let unified = gliff.to_unified(edits, old_name: "old", new_name: "new")
      io.println(unified)
    }
    Truncated(edits:) -> {
      io.println("Status: Truncated (budget exceeded)")
      let unified = gliff.to_unified(edits, old_name: "old", new_name: "new")
      io.println(unified)
    }
  }
}
