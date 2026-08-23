#!/usr/bin/env python3
"""router-bench - A/B tool-calling benchmark for Hermes router model candidates.

Gives each model the same routing system prompt + a `delegate` tool, fires a set
of prompts with a known-correct target specialist, and scores correctness +
latency + valid-tool-call rate. Picks the best router on data, not vibes.
"""
import json, os, re, time, urllib.request, urllib.error
from concurrent.futures import ThreadPoolExecutor

ENV = os.path.expanduser("~/.hermes/.env")
KEY = ""
for line in open(ENV):
    if line.startswith("OPENROUTER_API_KEY="):
        KEY = line.split("=", 1)[1].strip()
ASSERT = KEY or exit("no OPENROUTER_API_KEY")

MODELS = [
    "google/gemini-3.1-flash-lite",
    "google/gemini-3.1-flash-lite-preview",
    "google/gemini-3-flash-preview",
    "deepseek/deepseek-v4-flash",
    "deepseek/deepseek-v4-pro",
]

SPECIALISTS = ["mike-ross", "harvey-specter", "ruth-langmore", "mike-ehrmantraut",
               "gus-fring", "penelope-featherington", "donna-paulsen", "marty-byrde",
               "jesse-pinkman", "none"]

SYS = (
    "You are Joe's router. For each request, decide which specialist handles it and "
    "call the `delegate` tool exactly once. Use 'none' only for trivial lookups you'd "
    "answer directly. Routing:\n"
    "- mike-ross: architecture, code, debugging, AWS/Power Platform engineering\n"
    "- harvey-specter: CREATING/refining user stories + acceptance criteria\n"
    "- ruth-langmore: sprint status, blockers, board tracking, capacity (NOT writing stories)\n"
    "- mike-ehrmantraut: 'is this allowed here', compliance, who approves\n"
    "- gus-fring: platform strategy, where the market is heading, build-or-not\n"
    "- penelope-featherington: exec decks, published summaries, exec voice\n"
    "- donna-paulsen: personal life admin, scheduling, bills, insurance\n"
    "- marty-byrde: markets, portfolio, position sizing, trading\n"
    "- jesse-pinkman: eval/sandbox/stress-testing a new capability\n"
)

TOOL = [{
    "type": "function",
    "function": {
        "name": "delegate",
        "description": "Route the request to exactly one specialist (or 'none' to answer directly).",
        "parameters": {
            "type": "object",
            "properties": {
                "specialist": {"type": "string", "enum": SPECIALISTS},
                "task": {"type": "string", "description": "the task text to hand the specialist"},
            },
            "required": ["specialist", "task"],
        },
    },
}]

# (prompt, expected specialist)
CASES = [
    ("Audit our AWS Lambda timeout settings across us-east-1 and propose fixes.", "mike-ross"),
    ("What's my current sprint status and what's blocked right now?", "ruth-langmore"),
    ("Break the new SSO login feature into user stories with acceptance criteria.", "harvey-specter"),
    ("Draft an executive summary of Q2 delivery for the leadership deck.", "penelope-featherington"),
    ("Review my portfolio and tell me whether to resize any positions.", "marty-byrde"),
    ("Where is the enterprise agent-platform market heading over the next year?", "gus-fring"),
    ("Reschedule my dentist appointment and pay this month's car loan.", "donna-paulsen"),
]


def call(model, prompt):
    body = json.dumps({
        "model": model,
        "messages": [{"role": "system", "content": SYS}, {"role": "user", "content": prompt}],
        "tools": TOOL,
        "tool_choice": "auto",
        "temperature": 0,
        "max_tokens": 300,
    }).encode()
    req = urllib.request.Request(
        "https://openrouter.ai/api/v1/chat/completions", data=body, method="POST",
        headers={"Authorization": f"Bearer {KEY}", "Content-Type": "application/json"})
    t0 = time.time()
    try:
        resp = urllib.request.urlopen(req, timeout=60)
        dt = time.time() - t0
        data = json.loads(resp.read())
        msg = data.get("choices", [{}])[0].get("message", {})
        calls = msg.get("tool_calls") or []
        if not calls:
            # some models put the call in content; try to salvage
            return {"ok_call": False, "specialist": None, "dt": dt, "raw": (msg.get("content") or "")[:60]}
        args = calls[0].get("function", {}).get("arguments", "{}")
        try:
            spec = json.loads(args).get("specialist")
        except Exception:
            m = re.search(r'"?specialist"?\s*[:=]\s*"?([a-z-]+)', args)
            spec = m.group(1) if m else None
        return {"ok_call": True, "specialist": spec, "dt": dt, "raw": ""}
    except urllib.error.HTTPError as e:
        return {"ok_call": False, "specialist": None, "dt": time.time() - t0, "raw": f"HTTP {e.code}: {e.read()[:80]}"}
    except Exception as e:
        return {"ok_call": False, "specialist": None, "dt": time.time() - t0, "raw": str(e)[:80]}


def bench(model):
    correct = 0
    valid = 0
    lat = []
    errs = []
    for prompt, expected in CASES:
        r = call(model, prompt)
        lat.append(r["dt"])
        if r["ok_call"]:
            valid += 1
            if r["specialist"] == expected:
                correct += 1
            else:
                errs.append(f"{expected}->{r['specialist']}")
        else:
            errs.append(f"NO_CALL({r['raw'][:30]})")
    return {
        "model": model, "correct": correct, "valid": valid, "n": len(CASES),
        "avg_lat": sum(lat) / len(lat), "p_max": max(lat), "errs": errs,
    }


def main():
    print(f"Benchmarking {len(MODELS)} models x {len(CASES)} routing cases...\n")
    results = []
    with ThreadPoolExecutor(max_workers=len(MODELS)) as ex:
        for r in ex.map(bench, MODELS):
            results.append(r)
    results.sort(key=lambda r: (-r["correct"], r["avg_lat"]))
    print(f"{'MODEL':<42} {'CORRECT':>8} {'VALID':>7} {'AVG':>7} {'MAX':>7}")
    print("-" * 80)
    for r in results:
        print(f"{r['model']:<42} {r['correct']:>3}/{r['n']:<4} {r['valid']:>3}/{r['n']:<3} "
              f"{r['avg_lat']:>6.2f}s {r['p_max']:>6.2f}s")
        if r["errs"]:
            print(f"    misses: {', '.join(r['errs'])}")
    print()


if __name__ == "__main__":
    main()
