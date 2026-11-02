const test = require("node:test");
const assert = require("node:assert");
const { greet } = require("./greet");

test("greets by name", () => {
  assert.strictEqual(greet("Ana"), "Hello, Ana!");
});
