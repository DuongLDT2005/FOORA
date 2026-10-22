const assert = require("node:assert/strict");
const test = require("node:test");

const {
  INVITE_CODE_ALPHABET,
  INVITE_CODE_LENGTH,
  generateInviteCode,
  isValidInviteCode,
  normalizeInviteCode,
} = require("../lib/household/services/invite_code.js");

test("generated codes have 6 characters from the alphabet", () => {
  for (let i = 0; i < 500; i++) {
    const code = generateInviteCode();
    assert.equal(code.length, INVITE_CODE_LENGTH);
    for (const char of code) {
      assert.ok(INVITE_CODE_ALPHABET.includes(char), `unexpected ${char}`);
    }
    assert.ok(isValidInviteCode(code));
  }
});

test("alphabet excludes look-alike characters", () => {
  for (const char of ["0", "O", "1", "I", "L"]) {
    assert.ok(!INVITE_CODE_ALPHABET.includes(char));
  }
});

test("normalize upper-cases and strips spaces and dashes", () => {
  assert.equal(normalizeInviteCode(" ab cd 2 3 "), "ABCD23");
  assert.equal(normalizeInviteCode("abc-d23"), "ABCD23");
});

test("validation rejects ambiguous characters and wrong length", () => {
  assert.ok(isValidInviteCode("ABCD23"));
  assert.ok(!isValidInviteCode("ABCD2"));
  assert.ok(!isValidInviteCode("ABCD234"));
  for (const code of ["ABCD20", "ABCDO3", "ABCD13", "ABCDI3", "ABCDL3"]) {
    assert.ok(!isValidInviteCode(code), code);
  }
});
