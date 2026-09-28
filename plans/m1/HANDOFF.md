# Handoff: `/explain` — narrated code-explainer videos

Written 2026-09-27 at the end of a design conversation. Read this fully before planning.

## Goal

A new skill, `skills/explain/`, that turns a code repository into a narrated explainer video of about 5–8 minutes. The reference is a ~7-minute SQLite explainer (the user has the link; ask for it if you want to study its pacing). The video has five chapters:

1. **What it is:** what the repo does and why it's useful.
2. **Code map:** a high-level map of the codebase as a beautiful animated graphic.
3. **The life of a request:** one real input traced through the real call path (for SQLite, a query).
4. **Core abstractions:** the handful of types or modules everything else hangs off.
5. **Real execution trace:** what actually happens at runtime, captured from a real run. For SQLite this includes join-order query planning.

## Decisions already made (don't re-litigate)

- **A sibling skill, not a new `/brag` input type.** Nearly all of brag's rules change: length (minutes, not 15–25s), what drives the timing (narration, not music), voice (required, not opt-in), and the main risk (being wrong, not being boring).
- **Build on `/brag-slim`, not the full Hyperframes `/brag`.** Reuse the structure of `skills/brag-slim/SKILL.md`: a single file with Inspect → Plan → Build/check/render → Deliver, "frames are a pure function of time", checking stills before the render, and the frame-0 poster step. Don't modify `skills/brag*`. The check script requires `skills/brag/slim.md` and `skills/brag-slim/SKILL.md` to stay identical.
- **Accuracy is the top rule.** Every on-screen claim about the code must trace back to a `file:line` or a captured log line. Keep a `claims.md` that records the source of each claim. Before the render, a reviewer subagent with no prior context checks `claims.md` against the repo. Never invent function names, call paths, or trace output.
- **Narration comes first.** Write the script for each chapter, generate the audio, measure its length, then time the visuals to it. (Brag does the reverse and times visuals to the music.)
- **Render each chapter separately, then join them with ffmpeg.** Seven minutes in one render is fragile, and chapters need to be redone independently.
- **Code map source:** the `graphify` skill (`~/.claude/skills/graphify/SKILL.md`), which builds a knowledge graph with clusters of related code and the most-connected components. Use it instead of having the model guess the architecture; chapter 4's abstractions come from the same graph. Draw the map as dependency-free inline SVG, animated cluster by cluster (user prior: plain SVG over graph libraries).
- **Traces are captured, not written.** Run the target program and save the raw output to `work/traces/`. The video shows only what those files contain. For SQLite, use `EXPLAIN` (VM bytecode) and `EXPLAIN QUERY PLAN` (join order).

## Scope of the first milestone (build this first)

**M1: a minimal end-to-end version covering chapters 1 and 2 only, about 90 seconds, on one small repo the user knows.** It proves the two new mechanisms, narration-timed visuals and the animated code map, before anything else gets built. Chapters 3–5 are later milestones: M2 adds chapter 3 (the request's path through real code snippets), M3 adds chapter 4, and M4 adds chapter 5 (trace capture, SQLite first).

M1 is done when:
- `/explain` in a target repo produces `explain-output/explain.mp4` (chapters 1–2 with narration), plus `script.md`, `claims.md`, `explain.jpg` (baked into frame 0), and `share-copy.txt`.
- Every node and label in the code map exists in the graphify output, and every claim in `claims.md` has a source.
- A reviewer subagent with no prior context has checked `claims.md` against the repo and found no unsupported claims.
- `node scripts/check-docs.mjs && node scripts/check-brag-slim.mjs` still pass.

## Open questions (ask the user; these decisions are expensive to change later)

1. **TTS engine.** Options include Kokoro via `npx hyperframes tts` (already used by `/brag --voice`), macOS `say` (zero dependencies, lower quality), or a hosted API (external calls, cost). This adds a dependency, so ask.
2. **Target repo for M1:** a small repo the user knows well. SQLite is the M4 benchmark, not the M1 target.
3. **Install path for trying it:** probably symlink `skills/explain` into `~/.claude/skills/explain`. That's outside the repo, so the user does it or approves it.

## Unverified (check before relying on it)

- SQLite has a `.wheretrace` shell command that logs how the planner costs join orders, but it may need a `SQLITE_DEBUG` build. The system `sqlite3` is 3.43.2 (Apple build, almost certainly not a debug build). If join-cost traces need a custom build, that becomes an M4 ticket.
- Whether Hyperframes' `tts` command runs standalone, without composing through Hyperframes. Test it before choosing it.

## Repo facts

- Fork: `origin` = `github.com/jwolberg/brag`, `upstream` = `latent-spaces/brag`. Work branch: `feat/explain`. Never push to `upstream`, and push to `origin` only when the user asks.
- **`docs/` is the GitHub Pages deploy root**, so don't write implementation notes there. Use `plans/explain/implementation-notes.md` instead of the global default `docs/implementation-notes.md`, and log that deviation as the first entry.
- Validation gate (no package.json, no test suite): `node scripts/check-docs.mjs && node scripts/check-brag-slim.mjs`. Both passed on 2026-09-27.
- Tooling on this machine: node 22.14, ffmpeg, uv, python3.10, sqlite3 3.43.2.
- Output folders to gitignore: `explain-output*/` (as `brag-output*/` already is).
- If `/explain` becomes public, add `.claude/skills/explain`, `.agents/skills/explain` and `.opencode/skills/explain` symlinks following the existing pattern. That can wait until after M1.
