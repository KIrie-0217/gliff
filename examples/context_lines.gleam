//// Output:
////
////   === Default (3 lines context) ===
////   --- a.txt
////   +++ b.txt
////   @@ -2,7 +2,7 @@
////    2
////    3
////    4
////   -5
////   +X
////    6
////    7
////    8
////
////   === 1 line context ===
////   --- a.txt
////   +++ b.txt
////   @@ -4,3 +4,3 @@
////    4
////   -5
////   +X
////    6
////
////   === 0 lines context ===
////   --- a.txt
////   +++ b.txt
////   @@ -5,1 +5,1 @@
////   -5
////   +X

import gleam/io
import gliff

pub fn main() {
  let old = "1\n2\n3\n4\n5\n6\n7\n8\n9"
  let new = "1\n2\n3\n4\nX\n6\n7\n8\n9"
  let edits = gliff.diff(old, new)

  io.println("=== Default (3 lines context) ===")
  let default = gliff.to_unified(edits, old_name: "a.txt", new_name: "b.txt")
  io.print(default)

  io.println("")
  io.println("=== 1 line context ===")
  let ctx1 =
    gliff.to_unified_with(
      edits,
      old_name: "a.txt",
      new_name: "b.txt",
      context: 1,
    )
  io.print(ctx1)

  io.println("")
  io.println("=== 0 lines context ===")
  let ctx0 =
    gliff.to_unified_with(
      edits,
      old_name: "a.txt",
      new_name: "b.txt",
      context: 0,
    )
  io.print(ctx0)
}
