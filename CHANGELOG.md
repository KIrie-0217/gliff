# Changelog

## 1.1.0

### Added

- **Configurable context lines** — `to_unified_with` allows specifying context line count (equivalent to `diff -U<n>`)
- **ANSI color output** — `to_ansi` renders colored unified diffs for terminal display; `to_ansi_inline` adds bold highlighting for changed characters
- **Fuzzy patch application** — `apply_patch_fuzzy` accepts slightly modified text using character-level similarity scoring with configurable tolerance
- **3-way merge** — `merge3` combines two diverged versions, detecting conflicts with Git-style `<<<<<<<`/`=======`/`>>>>>>>` markers
- **Automated hex.pm publishing** — GitHub Actions workflow publishes to hex on release

## 1.0.0

Initial stable release.

### Features

- **Myers diff** — optimal O(ND) edit distance algorithm with common prefix/suffix optimization
- **Patience diff** — anchors on unique lines for readable output on reordered code
- **Line, word, and character-level diffing** — `diff`, `diff_words`, `diff_chars`
- **Unified diff format** — `to_unified` / `from_unified` compatible with `diff -u` and `patch`
- **Patch application** — `apply_patch` with the roundtrip property: `apply_patch(old, diff(old, new)) == Ok(new)`
- **Semantic cleanup** — `cleanup_semantic` eliminates trivial equalities; `cleanup_semantic_lossless` shifts boundaries to natural positions
- **Inline highlighting** — `inline_highlight` provides character-level change spans within modified lines
- **Similarity ratio** — `similarity` returns 0.0 to 1.0 based on matching content
- **Configurable API** — `diff_with` / `diff_chars_with` with algorithm selection, cleanup mode, and iteration budget
- **Iteration budget** — graceful fallback for large inputs via `max_iterations` in `DiffConfig`
- **Pure Gleam** — no FFI, works on both Erlang and JavaScript targets
- **Zero dependencies** — only `gleam_stdlib`
