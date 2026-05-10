//// Output:
////
////   === Exact Patch (fails) ===
////   Error: patch cannot be applied to modified text
////
////   === Fuzzy Patch (tolerance: 0.6) ===
////   Success! Patched text:
////   hello world
////   new content
////   goodbye

import gleam/io
import gliff

pub fn main() {
  let old = "hello world\nold content\ngoodbye"
  let new = "hello world\nnew content\ngoodbye"
  let edits = gliff.diff(old, new)

  // Text has been slightly modified (trailing spaces added)
  let modified = "hello world  \nold content \ngoodbye"

  io.println("=== Exact Patch (fails) ===")
  case gliff.apply_patch(modified, edits) {
    Ok(_) -> io.println("Success (unexpected)")
    Error(_) -> io.println("Error: patch cannot be applied to modified text")
  }

  io.println("")
  io.println("=== Fuzzy Patch (tolerance: 0.6) ===")
  case gliff.apply_patch_fuzzy(modified, edits, tolerance: 0.6) {
    Ok(result) -> {
      io.println("Success! Patched text:")
      io.println(result)
    }
    Error(e) -> io.println("Error: " <> e)
  }
}
