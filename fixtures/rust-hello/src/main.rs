fn greeting() -> &'static str {
    "hello from the rust-gate self-test fixture"
}

fn main() {
    println!("{}", greeting());
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn greeting_names_the_fixture() {
        assert_eq!(greeting(), "hello from the rust-gate self-test fixture");
    }
}
