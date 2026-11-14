// KeyMap.js — pure key resolution for wheel-hover-launcher.
// No Qt imports: usable from QML (`import "KeyMap.js" as KeyMap`) and node tests.

/**
 * Resolve per-sector keyboard keys from apps.json entries.
 *
 * Pass 1: each app with a non-empty `key` claims it (lowercased, single char).
 *         First claim wins on duplicates; losers fall through to pass 2.
 * Pass 2: apps still without a key get defaults[i] (positional homerow)
 *         only if unclaimed; otherwise "" (mouse-only).
 *
 * @param {Array<{key?: string}>} apps
 * @param {string[]} defaults  positional homerow keys, e.g. ["a","s",...]
 * @returns {string[]} key per app index, "" = no keyboard shortcut
 */
function resolveKeys(apps, defaults) {
    var list = apps || []
    var defs = defaults || []
    var n = list.length
    var result = []
    var claimed = Object.create(null)
    var i

    for (i = 0; i < n; i++)
        result[i] = ""

    // Pass 1 — custom keys from apps.json
    for (i = 0; i < n; i++) {
        var entry = list[i]
        if (!entry || entry.key === undefined || entry.key === null)
            continue
        var k = String(entry.key).trim().toLowerCase()
        if (k === "")
            continue // missing/empty → pass 2 fallback
        if (k.length !== 1) {
            console.warn("wheel-hover-launcher: key must be a single character, got: " + k)
            continue
        }
        if (claimed[k] !== undefined) {
            // duplicate custom key — first app keeps it
            console.warn("wheel-hover-launcher: duplicate key '" + k + "' on app index " + i
                + ", already used by index " + claimed[k])
            continue
        }
        claimed[k] = i
        result[i] = k
    }

    // Pass 2 — positional homerow defaults for apps without a custom key
    for (i = 0; i < n; i++) {
        if (result[i] !== "")
            continue
        var d = i < defs.length ? defs[i] : ""
        if (d === "")
            continue // beyond homerow list → mouse-only
        if (claimed[d] !== undefined)
            continue // stolen by a custom key → mouse-only
        claimed[d] = i
        result[i] = d
    }

    return result
}

/**
 * Whether dwell auto-launch may run.
 * Requires Ctrl or Alt held and a highlighted sector.
 * Plain hover never dwells; releasing the modifier must cancel
 * (caller stops the timer).
 *
 * @param {boolean} modifierHeld  Ctrl or Alt currently down
 * @param {number} highlightIndex -1 = nothing under cursor
 * @returns {boolean}
 */
function shouldDwell(modifierHeld, highlightIndex) {
    return !!modifierHeld && highlightIndex >= 0
}

// node test hook (QML ignores this — `module` is undefined there)
if (typeof module !== "undefined" && module.exports) {
    module.exports = {
        resolveKeys: resolveKeys,
        shouldDwell: shouldDwell
    }
}
