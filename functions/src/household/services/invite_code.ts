import * as crypto from "crypto";

/**
 * Invite code alphabet without look-alike characters (0/O, 1/I/L), so codes
 * read aloud or typed by hand are unambiguous. 31^6 ≈ 887M combinations.
 */
export const INVITE_CODE_ALPHABET = "ABCDEFGHJKMNPQRSTUVWXYZ23456789";
export const INVITE_CODE_LENGTH = 6;
export const INVITE_CODE_PATTERN = /^[A-HJKMNP-Z2-9]{6}$/;

/**
 * Generates a cryptographically random invite code.
 * @return {string} A 6-character code from INVITE_CODE_ALPHABET.
 */
export function generateInviteCode(): string {
  return Array.from(
    {length: INVITE_CODE_LENGTH},
    () => INVITE_CODE_ALPHABET[crypto.randomInt(INVITE_CODE_ALPHABET.length)]
  ).join("");
}

/**
 * Normalizes user input: upper-case, drops whitespace and dashes.
 * @param {string} raw Code as typed by the user.
 * @return {string} Normalized code (may still be invalid).
 */
export function normalizeInviteCode(raw: string): string {
  return raw.toUpperCase().replace(/[\s-]/g, "");
}

/**
 * Checks that a normalized code has the expected shape.
 * @param {string} code Normalized code.
 * @return {boolean} True when the code can exist.
 */
export function isValidInviteCode(code: string): boolean {
  return INVITE_CODE_PATTERN.test(code);
}
