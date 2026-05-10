pub type Budget {
  Unlimited
  Limited(remaining: Int)
}

pub fn from_max(max: Int) -> Budget {
  case max <= 0 {
    True -> Unlimited
    False -> Limited(max)
  }
}

pub fn tick(budget: Budget) -> Result(Budget, Nil) {
  case budget {
    Unlimited -> Ok(Unlimited)
    Limited(remaining) if remaining > 0 -> Ok(Limited(remaining - 1))
    Limited(_) -> Error(Nil)
  }
}
