// Unit tests for KeyMap — run: node tests/keymap.test.js
const assert = require("assert")
const { resolveKeys, shouldDwell } = require("../KeyMap.js")

const HOME = ["a", "s", "d", "f", "g", "h", "j", "k", "l", ";"]
let passed = 0

function test(name, fn) {
    fn()
    passed++
    console.log("ok - " + name)
}

test("all missing keys → positional homerow", () => {
    const apps = [{ name: "A" }, { name: "B" }, { name: "C" }]
    assert.deepStrictEqual(resolveKeys(apps, HOME), ["a", "s", "d"])
})

test("empty string key → same as missing (homerow fallback)", () => {
    const apps = [{ name: "A", key: "" }, { name: "B" }]
    assert.deepStrictEqual(resolveKeys(apps, HOME), ["a", "s"])
})

test("custom key overrides positional default", () => {
    const apps = [{ name: "A", key: "t" }, { name: "B" }]
    assert.deepStrictEqual(resolveKeys(apps, HOME), ["t", "s"])
})

test("case / whitespace normalization", () => {
    const apps = [{ name: "A", key: " T " }]
    assert.deepStrictEqual(resolveKeys(apps, HOME), ["t"])
})

test("custom steals homerow from another app → victim mouse-only", () => {
    // app1 claims "a"; app0's default "a" is gone
    const apps = [{ name: "A" }, { name: "B", key: "a" }]
    assert.deepStrictEqual(resolveKeys(apps, HOME), ["", "a"])
})

test("duplicate custom keys → first wins, second falls through", () => {
    // app0 claims "t"; app1 wants "t" (dup) → pass2 wants "s" (free)
    const apps = [{ name: "A", key: "t" }, { name: "B", key: "t" }]
    assert.deepStrictEqual(resolveKeys(apps, HOME), ["t", "s"])
})

test("duplicate where fallback also stolen → second mouse-only", () => {
    // app0 key "s" claims s; app1 key "s" dup → pass2 wants s (stolen)
    const apps = [{ name: "A", key: "s" }, { name: "B", key: "s" }]
    assert.deepStrictEqual(resolveKeys(apps, HOME), ["s", ""])
})

test("multi-char custom key rejected → homerow fallback", () => {
    const apps = [{ name: "A", key: "ab" }]
    assert.deepStrictEqual(resolveKeys(apps, HOME), ["a"])
})

test("beyond homerow list without custom → mouse-only", () => {
    const apps = Array.from({ length: 11 }, (_, i) => ({ name: "X" + i }))
    const r = resolveKeys(apps, HOME)
    assert.strictEqual(r.length, 11)
    assert.strictEqual(r[10], "")
    assert.deepStrictEqual(r.slice(0, 10), HOME)
})

test("null / undefined apps safe", () => {
    assert.deepStrictEqual(resolveKeys(null, HOME), [])
    assert.deepStrictEqual(resolveKeys(undefined, []), [])
})

test("null key field treated as missing", () => {
    const apps = [{ name: "A", key: null }, { name: "B" }]
    assert.deepStrictEqual(resolveKeys(apps, HOME), ["a", "s"])
})

// ---- shouldDwell (Ctrl/Alt-gated hover auto-launch) ----

test("shouldDwell: requires modifier held (plain hover = no dwell)", () => {
    assert.strictEqual(shouldDwell(false, 0), false)
})

test("shouldDwell: requires a highlighted sector", () => {
    assert.strictEqual(shouldDwell(true, -1), false)
})

test("shouldDwell: modifier + sector → true (no autoLaunch flag)", () => {
    assert.strictEqual(shouldDwell(true, 0), true)
    assert.strictEqual(shouldDwell(true, 3), true)
})

console.log("\n" + passed + " tests passed")
