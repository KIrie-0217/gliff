//// Output:
////
////   === Myers Diff ===
////   --- old.py
////   +++ new.py
////   @@ -1,8 +1,8 @@
////   -def foo():
////   -    return 1
////   -
////    def bar():
////        return 2
////   +
////   +def foo():
////   +    return 1
////
////    def baz():
////        return 3
////
////   === Patience Diff ===
////   --- old.py
////   +++ new.py
////   @@ -1,8 +1,8 @@
////   -def foo():
////   -    return 1
////   -
////    def bar():
////        return 2
////   +
////   +def foo():
////   +    return 1
////
////    def baz():
////        return 3

import gleam/io
import gliff

pub fn main() {
  // Patience diff excels when code blocks are reordered
  let old =
    "def foo():\n    return 1\n\ndef bar():\n    return 2\n\ndef baz():\n    return 3"
  let new =
    "def bar():\n    return 2\n\ndef foo():\n    return 1\n\ndef baz():\n    return 3"

  io.println("=== Myers Diff ===")
  let myers_edits = gliff.diff(old, new)
  let myers_unified =
    gliff.to_unified(myers_edits, old_name: "old.py", new_name: "new.py")
  io.println(myers_unified)

  io.println("=== Patience Diff ===")
  let patience_edits = gliff.diff_patience(old, new)
  let patience_unified =
    gliff.to_unified(patience_edits, old_name: "old.py", new_name: "new.py")
  io.println(patience_unified)
}
