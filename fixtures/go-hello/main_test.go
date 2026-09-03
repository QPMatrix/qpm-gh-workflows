package main

import "testing"

func TestGreetingNamesTheFixture(t *testing.T) {
	want := "hello from the go-gate self-test fixture"
	if got := greeting(); got != want {
		t.Fatalf("greeting() = %q, want %q", got, want)
	}
}
