const fs = require("fs");
const path = require("path");

const FILE = path.join(__dirname, "data", "users.json");

function loadUsers() {
  return JSON.parse(fs.readFileSync(FILE, "utf8"));
}

function saveUsers(users) {
  fs.writeFileSync(FILE, JSON.stringify(users, null, 2) + "\n");
}

module.exports = { loadUsers, saveUsers };
