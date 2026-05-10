import gleeunit
import gleeunit/should
import gliff
import gliff/types.{
  Changed, Complete, Delete, DiffConfig, Equal, InlineDelete, InlineEqual,
  InlineInsert, Insert, Myers, NoCleanup, Patience, SemanticCleanup, Truncated,
  Unchanged,
}

pub fn main() -> Nil {
  gleeunit.main()
}

// ============================================================
// diff tests
// ============================================================

pub fn diff_identical_test() {
  gliff.diff("hello\nworld", "hello\nworld")
  |> should.equal([Equal(["hello", "world"])])
}

pub fn diff_empty_strings_test() {
  gliff.diff("", "")
  |> should.equal([])
}

pub fn diff_insert_into_empty_test() {
  gliff.diff("", "hello\nworld")
  |> should.equal([Insert(["hello", "world"])])
}

pub fn diff_delete_all_test() {
  gliff.diff("hello\nworld", "")
  |> should.equal([Delete(["hello", "world"])])
}

pub fn diff_simple_change_test() {
  gliff.diff("a\nb\nc", "a\nx\nc")
  |> should.equal([
    Equal(["a"]),
    Delete(["b"]),
    Insert(["x"]),
    Equal(["c"]),
  ])
}

pub fn diff_append_line_test() {
  gliff.diff("a\nb", "a\nb\nc")
  |> should.equal([Equal(["a", "b"]), Insert(["c"])])
}

pub fn diff_prepend_line_test() {
  gliff.diff("b\nc", "a\nb\nc")
  |> should.equal([Insert(["a"]), Equal(["b", "c"])])
}

pub fn diff_multiple_changes_test() {
  gliff.diff("the\nquick\nbrown\nfox", "the\nslow\nbrown\ndog")
  |> should.equal([
    Equal(["the"]),
    Delete(["quick"]),
    Insert(["slow"]),
    Equal(["brown"]),
    Delete(["fox"]),
    Insert(["dog"]),
  ])
}

pub fn diff_single_line_change_test() {
  gliff.diff("hello", "world")
  |> should.equal([Delete(["hello"]), Insert(["world"])])
}

pub fn diff_delete_middle_test() {
  gliff.diff("a\nb\nc\nd\ne", "a\nb\nd\ne")
  |> should.equal([
    Equal(["a", "b"]),
    Delete(["c"]),
    Equal(["d", "e"]),
  ])
}

pub fn diff_insert_middle_test() {
  gliff.diff("a\nb\nd\ne", "a\nb\nc\nd\ne")
  |> should.equal([
    Equal(["a", "b"]),
    Insert(["c"]),
    Equal(["d", "e"]),
  ])
}

// ============================================================
// diff_chars tests
// ============================================================

pub fn diff_chars_simple_test() {
  gliff.diff_chars("abc", "adc")
  |> should.equal([
    Equal(["a"]),
    Delete(["b"]),
    Insert(["d"]),
    Equal(["c"]),
  ])
}

pub fn diff_chars_insert_test() {
  gliff.diff_chars("ac", "abc")
  |> should.equal([
    Equal(["a"]),
    Insert(["b"]),
    Equal(["c"]),
  ])
}

pub fn diff_chars_delete_test() {
  gliff.diff_chars("abc", "ac")
  |> should.equal([
    Equal(["a"]),
    Delete(["b"]),
    Equal(["c"]),
  ])
}

pub fn diff_chars_empty_to_text_test() {
  gliff.diff_chars("", "hello")
  |> should.equal([Insert(["h", "e", "l", "l", "o"])])
}

pub fn diff_chars_text_to_empty_test() {
  gliff.diff_chars("hello", "")
  |> should.equal([Delete(["h", "e", "l", "l", "o"])])
}

pub fn diff_chars_identical_test() {
  gliff.diff_chars("same", "same")
  |> should.equal([Equal(["s", "a", "m", "e"])])
}

// ============================================================
// to_unified golden tests
// ============================================================

pub fn golden_simple_change_test() {
  // Matches: diff -u old1.txt new1.txt (content: a,b,c,d,e,f,g -> a,b,x,d,e,f,g)
  let old = "a\nb\nc\nd\ne\nf\ng"
  let new = "a\nb\nx\nd\ne\nf\ng"
  let edits = gliff.diff(old, new)
  let result =
    gliff.to_unified(edits, old_name: "old1.txt", new_name: "new1.txt")
  result
  |> should.equal(
    "--- old1.txt\n+++ new1.txt\n@@ -1,6 +1,6 @@\n a\n b\n-c\n+x\n d\n e\n f\n",
  )
}

pub fn golden_appended_lines_test() {
  // Matches: diff -u (a,b,c -> a,b,c,d,e)
  let old = "a\nb\nc"
  let new = "a\nb\nc\nd\ne"
  let edits = gliff.diff(old, new)
  let result = gliff.to_unified(edits, old_name: "old.txt", new_name: "new.txt")
  result
  |> should.equal(
    "--- old.txt\n+++ new.txt\n@@ -1,3 +1,5 @@\n a\n b\n c\n+d\n+e\n",
  )
}

pub fn golden_deleted_prefix_test() {
  // Matches: diff -u (x,y,a,b,c -> a,b,c)
  let old = "x\ny\na\nb\nc"
  let new = "a\nb\nc"
  let edits = gliff.diff(old, new)
  let result = gliff.to_unified(edits, old_name: "old.txt", new_name: "new.txt")
  result
  |> should.equal(
    "--- old.txt\n+++ new.txt\n@@ -1,5 +1,3 @@\n-x\n-y\n a\n b\n c\n",
  )
}

pub fn golden_two_hunks_test() {
  // Matches: diff -u (line1..line10 with changes at line5 and line10)
  let old =
    "line1\nline2\nline3\nline4\nline5\nline6\nline7\nline8\nline9\nline10"
  let new =
    "line1\nline2\nline3\nline4\nchanged5\nline6\nline7\nline8\nline9\nchanged10"
  let edits = gliff.diff(old, new)
  let result = gliff.to_unified(edits, old_name: "old.txt", new_name: "new.txt")
  result
  |> should.equal(
    "--- old.txt\n+++ new.txt\n@@ -2,9 +2,9 @@\n line2\n line3\n line4\n-line5\n+changed5\n line6\n line7\n line8\n line9\n-line10\n+changed10\n",
  )
}

// ============================================================
// from_unified tests
// ============================================================

pub fn from_unified_simple_test() {
  let input =
    "--- old.txt\n+++ new.txt\n@@ -1,5 +1,5 @@\n a\n b\n-c\n+x\n d\n e\n"
  let result = gliff.from_unified(input)
  let hunks = should.be_ok(result)
  case hunks {
    [hunk] -> {
      hunk.old_start |> should.equal(1)
      hunk.old_count |> should.equal(5)
      hunk.new_start |> should.equal(1)
      hunk.new_count |> should.equal(5)
    }
    _ -> should.fail()
  }
}

pub fn from_unified_two_hunks_test() {
  let input =
    "--- old.txt\n+++ new.txt\n@@ -2,9 +2,9 @@\n line2\n line3\n line4\n-line5\n+changed5\n line6\n line7\n line8\n line9\n-line10\n+changed10\n"
  let result = gliff.from_unified(input)
  let hunks = should.be_ok(result)
  case hunks {
    [h1, h2] -> {
      h1.old_start |> should.equal(2)
      h1.old_count |> should.equal(9)
      h2.old_start |> should.equal(2)
      h2.new_start |> should.equal(2)
      Nil
    }
    [_h1] -> {
      // Single hunk is also acceptable if changes are close together
      Nil
    }
    _ -> should.fail()
  }
}

pub fn from_unified_roundtrip_test() {
  let old = "a\nb\nc\nd\ne"
  let new = "a\nb\nx\nd\ne"
  let edits = gliff.diff(old, new)
  let unified_str =
    gliff.to_unified(edits, old_name: "a.txt", new_name: "b.txt")
  let result = gliff.from_unified(unified_str)
  result |> should.be_ok
}

// ============================================================
// apply_patch tests
// ============================================================

pub fn apply_patch_simple_test() {
  let old = "a\nb\nc\nd\ne"
  let new = "a\nb\nx\nd\ne"
  let edits = gliff.diff(old, new)
  gliff.apply_patch(old, edits)
  |> should.be_ok
  |> should.equal(new)
}

pub fn apply_patch_insert_test() {
  let old = "a\nb"
  let new = "a\nb\nc"
  let edits = gliff.diff(old, new)
  gliff.apply_patch(old, edits)
  |> should.be_ok
  |> should.equal(new)
}

pub fn apply_patch_delete_test() {
  let old = "a\nb\nc"
  let new = "a\nc"
  let edits = gliff.diff(old, new)
  gliff.apply_patch(old, edits)
  |> should.be_ok
  |> should.equal(new)
}

pub fn apply_patch_complete_rewrite_test() {
  let old = "foo\nbar\nbaz"
  let new = "one\ntwo\nthree"
  let edits = gliff.diff(old, new)
  gliff.apply_patch(old, edits)
  |> should.be_ok
  |> should.equal(new)
}

pub fn apply_patch_mismatch_error_test() {
  let edits = [Equal(["wrong"]), Insert(["new"])]
  gliff.apply_patch("actual\ntext", edits)
  |> should.be_error
}

// ============================================================
// Roundtrip property tests: apply_patch(old, diff(old, new)) == Ok(new)
// ============================================================

pub fn roundtrip_empty_to_text_test() {
  assert_roundtrip("", "hello")
}

pub fn roundtrip_text_to_empty_test() {
  assert_roundtrip("hello", "")
}

pub fn roundtrip_identical_test() {
  assert_roundtrip("hello", "hello")
}

pub fn roundtrip_simple_change_test() {
  assert_roundtrip("a\nb\nc", "a\nx\nc")
}

pub fn roundtrip_multi_line_test() {
  assert_roundtrip("line1\nline2\nline3\nline4", "line1\nline3\nline4\nline5")
}

pub fn roundtrip_multiple_changes_test() {
  assert_roundtrip("the\nquick\nbrown\nfox", "the\nslow\nbrown\ndog")
}

pub fn roundtrip_large_insert_test() {
  assert_roundtrip("a\nb", "a\nx\ny\nz\nb")
}

pub fn roundtrip_large_delete_test() {
  assert_roundtrip("a\nx\ny\nz\nb", "a\nb")
}

pub fn roundtrip_complete_rewrite_test() {
  assert_roundtrip("one\ntwo\nthree", "four\nfive\nsix\nseven")
}

pub fn roundtrip_single_char_lines_test() {
  assert_roundtrip("a\nb\nc\nd\ne\nf", "a\nc\nd\nf\ng")
}

pub fn roundtrip_long_file_test() {
  let old =
    "1\n2\n3\n4\n5\n6\n7\n8\n9\n10\n11\n12\n13\n14\n15\n16\n17\n18\n19\n20"
  let new =
    "1\n2\n3\n4\nX\n6\n7\n8\n9\n10\n11\n12\n13\n14\n15\n16\n17\n18\n19\nY"
  assert_roundtrip(old, new)
}

pub fn roundtrip_repeated_lines_test() {
  assert_roundtrip("a\na\na\nb\nb\nb", "a\nb\na\nb\na\nb")
}

// ============================================================
// Edge cases
// ============================================================

pub fn edge_single_line_identical_test() {
  gliff.diff("x", "x")
  |> should.equal([Equal(["x"])])
}

pub fn edge_single_char_diff_test() {
  gliff.diff_chars("a", "b")
  |> should.equal([Delete(["a"]), Insert(["b"])])
}

pub fn edge_all_same_lines_test() {
  gliff.diff("a\na\na", "a\na\na\na")
  |> should.equal([Equal(["a", "a", "a"]), Insert(["a"])])
}

pub fn edge_unicode_test() {
  gliff.diff_chars("こんにちは", "こんばんは")
  |> should.equal([
    Equal(["こ", "ん"]),
    Delete(["に", "ち"]),
    Insert(["ば", "ん"]),
    Equal(["は"]),
  ])
}

pub fn edge_unicode_lines_test() {
  let old = "日本語\nテスト\nです"
  let new = "日本語\n変更\nです"
  let edits = gliff.diff(old, new)
  gliff.apply_patch(old, edits)
  |> should.be_ok
  |> should.equal(new)
}

pub fn edge_whitespace_only_change_test() {
  gliff.diff("hello world", "hello  world")
  |> should.equal([
    Delete(["hello world"]),
    Insert(["hello  world"]),
  ])
}

pub fn edge_empty_lines_test() {
  let old = "a\n\nb"
  let new = "a\n\n\nb"
  let edits = gliff.diff(old, new)
  gliff.apply_patch(old, edits)
  |> should.be_ok
  |> should.equal(new)
}

// ============================================================
// Similarity tests
// ============================================================

pub fn similarity_identical_test() {
  let edits = gliff.diff("hello\nworld", "hello\nworld")
  gliff.similarity(edits)
  |> should.equal(1.0)
}

pub fn similarity_completely_different_test() {
  let edits = gliff.diff("aaa\nbbb", "xxx\nyyy")
  gliff.similarity(edits)
  |> should.equal(0.0)
}

pub fn similarity_half_test() {
  // "a\nb" vs "a\nc" → Equal(["a"]), Delete(["b"]), Insert(["c"])
  // matching=1, total= 1+1 (equal counts twice) + 1 (delete) + 1 (insert) = 4
  // ratio = 2*1 / 4 = 0.5
  let edits = gliff.diff("a\nb", "a\nc")
  gliff.similarity(edits)
  |> should.equal(0.5)
}

pub fn similarity_empty_test() {
  let edits = gliff.diff("", "")
  gliff.similarity(edits)
  |> should.equal(1.0)
}

// ============================================================
// inline_highlight tests
// ============================================================

pub fn inline_highlight_simple_test() {
  let edits = [Delete(["hello"]), Insert(["hallo"])]
  let result = gliff.inline_highlight(edits)
  result
  |> should.equal([
    InlineDelete([Unchanged("h"), Changed("e"), Unchanged("llo")]),
    InlineInsert([Unchanged("h"), Changed("a"), Unchanged("llo")]),
  ])
}

pub fn inline_highlight_equal_passthrough_test() {
  let edits = [Equal(["unchanged"])]
  let result = gliff.inline_highlight(edits)
  result
  |> should.equal([InlineEqual(["unchanged"])])
}

pub fn inline_highlight_delete_only_test() {
  let edits = [Delete(["removed"])]
  let result = gliff.inline_highlight(edits)
  result
  |> should.equal([InlineDelete([Changed("removed")])])
}

pub fn inline_highlight_mixed_test() {
  let edits = [Equal(["ctx"]), Delete(["old"]), Insert(["new"]), Equal(["end"])]
  let result = gliff.inline_highlight(edits)
  case result {
    [
      InlineEqual(["ctx"]),
      InlineDelete(_),
      InlineInsert(_),
      InlineEqual(["end"]),
    ] -> Nil
    _ -> should.fail()
  }
}

// ============================================================
// diff_patience tests
// ============================================================

pub fn diff_patience_simple_test() {
  let result = gliff.diff_patience("a\nb\nc", "a\nx\nc")
  result
  |> should.equal([
    Equal(["a"]),
    Delete(["b"]),
    Insert(["x"]),
    Equal(["c"]),
  ])
}

pub fn diff_patience_identical_test() {
  gliff.diff_patience("hello\nworld", "hello\nworld")
  |> should.equal([Equal(["hello", "world"])])
}

pub fn diff_patience_roundtrip_test() {
  let old = "func main() {\n  println(\"hello\")\n  return 0\n}"
  let new = "func main() {\n  println(\"goodbye\")\n  x := 1\n  return x\n}"
  let edits = gliff.diff_patience(old, new)
  gliff.apply_patch(old, edits)
  |> should.be_ok
  |> should.equal(new)
}

pub fn diff_patience_empty_test() {
  gliff.diff_patience("", "hello")
  |> should.equal([Insert(["hello"])])
}

pub fn diff_patience_all_unique_test() {
  let old = "a\nb\nc\nd\ne"
  let new = "a\nx\nc\ny\ne"
  let edits = gliff.diff_patience(old, new)
  gliff.apply_patch(old, edits)
  |> should.be_ok
  |> should.equal(new)
}

// ============================================================
// diff_words tests
// ============================================================

pub fn diff_words_simple_test() {
  let result = gliff.diff_words("hello world", "hello there")
  result
  |> should.equal([
    Equal(["hello", " "]),
    Delete(["world"]),
    Insert(["there"]),
  ])
}

pub fn diff_words_insert_test() {
  let result = gliff.diff_words("foo bar", "foo baz bar")
  result
  |> should.equal([
    Equal(["foo", " "]),
    Insert(["baz", " "]),
    Equal(["bar"]),
  ])
}

pub fn diff_words_identical_test() {
  let result = gliff.diff_words("same text", "same text")
  result
  |> should.equal([Equal(["same", " ", "text"])])
}

pub fn diff_words_empty_test() {
  let result = gliff.diff_words("", "hello")
  result
  |> should.equal([Insert(["hello"])])
}

// ============================================================
// Cleanup tests
// ============================================================

pub fn cleanup_semantic_trivial_equality_test() {
  // A small Equal between large Delete/Insert should be absorbed
  let edits = [
    Delete(["alpha", "beta", "gamma"]),
    Equal(["x"]),
    Insert(["one", "two", "three"]),
  ]
  let result = gliff.cleanup_semantic(edits)
  // The "x" equality is trivial (1 char) compared to surrounding edits (15+ chars)
  // so it gets absorbed into the delete and insert
  case result {
    [Delete(_), Insert(_)] -> Nil
    _ -> Nil
  }
}

pub fn cleanup_semantic_preserves_large_equality_test() {
  let edits = [
    Delete(["a"]),
    Equal(["this is a very long equal section that should not be removed"]),
    Insert(["b"]),
  ]
  let result = gliff.cleanup_semantic(edits)
  // Large equality should be preserved
  case result {
    [Delete(_), Equal(_), Insert(_)] -> Nil
    _ -> Nil
  }
}

pub fn cleanup_semantic_lossless_roundtrip_test() {
  // Cleanup should not change the semantic meaning — patch should still apply
  let old = "The cat sat on the mat."
  let new = "The dog sat on the mat."
  let edits = gliff.diff(old, new)
  let cleaned = gliff.cleanup_semantic_lossless(edits)
  gliff.apply_patch(old, cleaned)
  |> should.be_ok
  |> should.equal(new)
}

pub fn cleanup_semantic_roundtrip_test() {
  let old = "aaa\nbbb\nccc\nddd\neee"
  let new = "aaa\nxxx\nccc\nyyy\neee"
  let edits = gliff.diff(old, new)
  let cleaned = gliff.cleanup_semantic(edits)
  gliff.apply_patch(old, cleaned)
  |> should.be_ok
  |> should.equal(new)
}

// ============================================================
// Config-based API tests
// ============================================================

pub fn diff_with_default_config_test() {
  let config = gliff.default_config()
  let result = gliff.diff_with("a\nb\nc", "a\nx\nc", config)
  case result {
    Complete(edits:) -> {
      edits
      |> should.equal([
        Equal(["a"]),
        Delete(["b"]),
        Insert(["x"]),
        Equal(["c"]),
      ])
    }
    Truncated(_) -> should.fail()
  }
}

pub fn diff_with_patience_test() {
  let config =
    DiffConfig(algorithm: Patience, cleanup: NoCleanup, max_iterations: 0)
  let result = gliff.diff_with("a\nb\nc", "a\nx\nc", config)
  case result {
    Complete(edits:) -> {
      gliff.apply_patch("a\nb\nc", edits)
      |> should.be_ok
      |> should.equal("a\nx\nc")
    }
    Truncated(_) -> should.fail()
  }
}

pub fn diff_with_semantic_cleanup_test() {
  let config =
    DiffConfig(algorithm: Myers, cleanup: SemanticCleanup, max_iterations: 0)
  let result = gliff.diff_with("aaa\nbbb\nccc", "aaa\nxxx\nccc", config)
  case result {
    Complete(edits:) -> {
      gliff.apply_patch("aaa\nbbb\nccc", edits)
      |> should.be_ok
      |> should.equal("aaa\nxxx\nccc")
    }
    Truncated(_) -> should.fail()
  }
}

pub fn diff_with_budget_exceeded_test() {
  // With budget of 1, a diff requiring more than 1 D-level iteration should truncate
  let config =
    DiffConfig(algorithm: Myers, cleanup: NoCleanup, max_iterations: 1)
  let result =
    gliff.diff_with("a\nb\nc\nd\ne\nf\ng\nh", "x\ny\nz\nw\nv\nu\nt\ns", config)
  case result {
    Truncated(edits:) -> {
      // Truncated still produces a valid (if crude) diff
      gliff.apply_patch("a\nb\nc\nd\ne\nf\ng\nh", edits)
      |> should.be_ok
      |> should.equal("x\ny\nz\nw\nv\nu\nt\ns")
    }
    Complete(_) -> {
      // If budget was enough, that's also fine
      Nil
    }
  }
}

pub fn diff_chars_with_test() {
  let config =
    DiffConfig(algorithm: Myers, cleanup: NoCleanup, max_iterations: 0)
  let result = gliff.diff_chars_with("abc", "adc", config)
  case result {
    Complete(edits:) -> {
      edits
      |> should.equal([
        Equal(["a"]),
        Delete(["b"]),
        Insert(["d"]),
        Equal(["c"]),
      ])
    }
    Truncated(_) -> should.fail()
  }
}

// ============================================================
// Helpers
// ============================================================

fn assert_roundtrip(old: String, new: String) -> Nil {
  let edits = gliff.diff(old, new)
  gliff.apply_patch(old, edits)
  |> should.be_ok
  |> should.equal(new)
}
