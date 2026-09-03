import { expect, test } from "bun:test";
import { greeting } from "./index";

test("greeting names the fixture", () => {
  expect(greeting()).toBe("hello from the ts-gate self-test fixture");
});
