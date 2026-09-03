// Command go-hello is the go-gate.yml self-test fixture (QPMSEC-570) — a
// real, tiny Go module exercised by go-gate.yml's format-lint/test/image
// jobs via self-test.yml's `working-directory: fixtures/go-hello`.
package main

import "fmt"

func greeting() string {
	return "hello from the go-gate self-test fixture"
}

func main() {
	fmt.Println(greeting())
}
