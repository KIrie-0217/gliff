//// Output (with ANSI colors rendered):
////
////   === Colored Unified Diff ===
////   --- old.txt
////   +++ new.txt
////   @@ -1,4 +1,4 @@
////    the
////   -quick brown
////   +slow brown
////    fox
////   -jumps
////   +leaps
////
////   === Inline Highlighting ===
////   - the [quick] brown
////   + the [slow] brown
////   - fox [jumps]
////   + fox [leaps]
////
////   (In the actual terminal, deletions are red, insertions green,
////    headers cyan, and [bracketed] parts are bold.)

import gleam/io
import gliff

pub fn main() {
  let old = "the\nquick brown\nfox\njumps"
  let new = "the\nslow brown\nfox\nleaps"

  io.println("=== Colored Unified Diff ===")
  let edits = gliff.diff(old, new)
  let colored = gliff.to_ansi(edits, old_name: "old.txt", new_name: "new.txt")
  io.print(colored)

  io.println("")
  io.println("=== Inline Highlighting ===")
  let inline = gliff.to_ansi_inline(edits)
  io.print(inline)
}
