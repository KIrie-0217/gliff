# Contributing to gliff

## Development Setup

```sh
gleam deps download
gleam test
```

## Workflow

1. Write implementation
2. Write tests
3. Ensure tests pass on both targets:
   ```sh
   gleam test
   gleam test --target javascript
   ```
4. Format code before committing:
   ```sh
   gleam format src test
   ```

## Design Principles

- **Pure Gleam** — no `@external` bindings. Must work on both BEAM and JavaScript.
- **Zero dependencies** beyond `gleam_stdlib`.
- **Correctness over performance** — match `diff -u` output exactly.
- **Composable API** — edits are data, not side effects.

## Project Structure

| Module | Responsibility |
|---|---|
| `gliff` | Public API |
| `gliff/types` | Shared type definitions |
| `gliff/internal/myers` | Myers diff algorithm |
| `gliff/internal/patience` | Patience diff algorithm |
| `gliff/internal/unified` | Unified diff formatting and parsing |
| `gliff/internal/patch` | Patch application |
| `gliff/internal/cleanup` | Semantic cleanup |
| `gliff/internal/tokenize` | Word tokenization |
| `gliff/internal/inline` | Inline change highlighting |
| `gliff/internal/similarity` | Similarity ratio |
| `gliff/internal/budget` | Iteration budget |

## Testing

- Property: `apply_patch(old, diff(old, new)) == Ok(new)` for all inputs
- Golden tests: compare output against `diff -u` for known inputs
- Edge cases: empty strings, identical strings, completely different strings, Unicode

## Pull Requests

- Ensure `gleam format --check src test` passes
- Ensure all tests pass on both Erlang and JavaScript targets
- Add tests for new functionality
