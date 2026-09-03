from hello_fixture import greeting


def test_greeting_names_the_fixture() -> None:
    assert greeting() == "hello from the python-gate self-test fixture"
