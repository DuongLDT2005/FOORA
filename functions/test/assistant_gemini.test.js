const assert = require("node:assert/strict");
const test = require("node:test");
const {generateAssistantJson, assistantModels} =
  require("../lib/ai/services/assistant_gemini.js");

process.env.AI_ASSISTANT_MODEL = "primary";
process.env.AI_ASSISTANT_FALLBACK_MODELS = "fallback,last";
const options = {timeoutMs: 1000, hedgeMs: 50};
const slowHedge = {timeoutMs: 1000, hedgeMs: 5000};
const answer = "{\"reply\":\"ok\",\"recipes\":[],\"actions\":[]}";
const acceptAll = () => true;

/**
 * Fake transport: each model answers with its outcome after a delay, or
 * rejects when the outcome is an error. A model without an outcome never
 * answers until aborted. Records calls and aborted signals.
 */
function fakeTransport(outcomes) {
  const calls = [];
  const aborted = [];
  return {
    calls,
    aborted,
    transport: {
      generate: async (model, _contents, signal) => {
        calls.push(model);
        return new Promise((resolve, reject) => {
          signal.addEventListener("abort", () => {
            aborted.push(model);
            reject(Object.assign(new Error("aborted"), {name: "AbortError"}));
          });
          const outcome = outcomes[model];
          if (!outcome) return;
          setTimeout(() => outcome.result instanceof Error ?
            reject(outcome.result) : resolve(outcome.result), outcome.delay ?? 0);
        });
      },
    },
  };
}

const status = (code) => Object.assign(new Error(`status ${code}`), {status: code});

test("reads the primary and the ordered fallback attempts from config", () => {
  assert.deepEqual(assistantModels(), ["primary", "fallback", "last"]);
});

test("returns the primary answer without starting another attempt", async () => {
  const fake = fakeTransport({primary: {result: answer}});
  const result = await generateAssistantJson("key", "{}", acceptAll,
    options, fake.transport);
  assert.deepEqual(result, {text: answer, model: "primary", accepted: true});
  await new Promise((resolve) => setTimeout(resolve, 120));
  assert.deepEqual(fake.calls, ["primary"]);
});

test("starts one more attempt per hedge delay and aborts the losers", async () => {
  const fake = fakeTransport({last: {delay: 10, result: answer}});
  const result = await generateAssistantJson("key", "{}", acceptAll,
    options, fake.transport);
  assert.equal(result.model, "last");
  assert.deepEqual(fake.calls, ["primary", "fallback", "last"]);
  assert.ok(fake.aborted.includes("primary") &&
    fake.aborted.includes("fallback"));
});

test("moves on at once after a failed, empty or rejected answer", async () => {
  for (const result of [status(503), " ", "{\"reply\":\"bad\"}"]) {
    const fake = fakeTransport({primary: {result}, fallback: {result: answer}});
    const started = Date.now();
    const outcome = await generateAssistantJson("key", "{}",
      (text) => text === answer, slowHedge, fake.transport);
    assert.equal(outcome.model, "fallback");
    assert.ok(Date.now() - started < 1000);
  }
});

test("returns the last rejected answer when nothing is approved", async () => {
  const fake = fakeTransport({
    primary: {result: "{\"reply\":\"a\"}"},
    fallback: {result: status(429)},
    last: {result: "{\"reply\":\"b\"}"},
  });
  const outcome = await generateAssistantJson("key", "{}", () => false,
    slowHedge, fake.transport);
  assert.deepEqual(outcome, {text: "{\"reply\":\"b\"}", model: "last",
    accepted: false});
});

test("maps the last error when every attempt fails", async () => {
  const fake = fakeTransport({
    primary: {result: status(429)},
    fallback: {result: status(503)},
    last: {result: status(429)},
  });
  await assert.rejects(generateAssistantJson("key", "{}", acceptAll,
    options, fake.transport), {code: "unavailable"});
});

test("stops at once when the key is rejected", async () => {
  const fake = fakeTransport({
    primary: {result: status(403)},
    fallback: {result: answer},
  });
  await assert.rejects(generateAssistantJson("key", "{}", acceptAll,
    slowHedge, fake.transport), {code: "failed-precondition"});
  assert.deepEqual(fake.calls, ["primary"]);
});

test("skips further attempts of a model that ran out of quota", async () => {
  process.env.AI_ASSISTANT_FALLBACK_MODELS = "primary,last";
  try {
    const fake = fakeTransport({
      primary: {result: status(429)},
      last: {result: answer},
    });
    const outcome = await generateAssistantJson("key", "{}", acceptAll,
      slowHedge, fake.transport);
    assert.equal(outcome.model, "last");
    assert.deepEqual(fake.calls, ["primary", "last"]);
  } finally {
    process.env.AI_ASSISTANT_FALLBACK_MODELS = "fallback,last";
  }
});
