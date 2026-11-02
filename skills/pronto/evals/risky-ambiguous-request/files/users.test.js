const test = require("node:test");
const assert = require("node:assert");
const { loadUsers } = require("./users");

test("loads all users", () => {
  assert.strictEqual(loadUsers().length, 5);
});
