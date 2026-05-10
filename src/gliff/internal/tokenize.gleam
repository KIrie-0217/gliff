import gleam/list
import gleam/string

pub fn words(text: String) -> List(String) {
  let graphemes = string.to_graphemes(text)
  tokenize_loop(graphemes, "", False, [])
  |> list.reverse
}

fn tokenize_loop(
  graphemes: List(String),
  current: String,
  in_whitespace: Bool,
  acc: List(String),
) -> List(String) {
  case graphemes {
    [] ->
      case current {
        "" -> acc
        _ -> [current, ..acc]
      }
    [g, ..rest] -> {
      let g_is_ws = is_whitespace(g)
      case g_is_ws == in_whitespace {
        True -> tokenize_loop(rest, current <> g, in_whitespace, acc)
        False ->
          case current {
            "" -> tokenize_loop(rest, g, g_is_ws, acc)
            _ -> tokenize_loop(rest, g, g_is_ws, [current, ..acc])
          }
      }
    }
  }
}

fn is_whitespace(g: String) -> Bool {
  g == " " || g == "\t" || g == "\n" || g == "\r"
}
