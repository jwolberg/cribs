# /cribs implementation notes

> M1 was built as `/explain` on the `feat/explain` branch of a fork of latent-spaces/brag (github.com/jwolberg/brag), then moved here and renamed `/cribs` on 2026-09-28. Paths and names below are as they were at the time: `skills/explain/` is now `skills/cribs/`, and `explain-output/` is now `cribs-output/`.

Running notes for the /explain build. Newest entries at the bottom.

## 2026-09-27 — Ticket 0001 (U1)

- **Deviation:** notes live here, not in `docs/implementation-notes.md` (the global default), because `docs/` is the GitHub Pages deploy root.
- **Open questions answered by the user:** TTS is Kokoro via `npx hyperframes tts`; the M1 target repo is this brag repo; Claude symlinks `skills/explain` into `~/.claude/skills/explain` in the final M1 ticket.
- **Decision:** `graphify-out/` is gitignored, since this repo is the M1 target and graphify writes there.
- **Decision:** demo media is kept out of graphify with a new `.graphifyignore` rather than `.gitignore`. The review caught that graphify would transcribe the ~10 tracked mp4s. Ignoring them in `.gitignore` would stop new gallery videos from being added.
- **Decision (not in the plan):** `.graphifyignore` also excludes `examples/`, not just `docs/`. The example sites are demo inputs for /brag, not part of brag's own code, and would crowd the code map.

## 2026-09-28 — Ticket 0002 (U2): Kokoro TTS standalone smoke test

- **Result: works standalone**, no Hyperframes composition needed, with two setup fixes the skill must carry.
- **Surprise 1:** `npx hyperframes tts` (v0.8.82) shells out to Python and needs `kokoro-onnx` + `soundfile`, which were not installed. Fix: a uv venv, passed via `HYPERFRAMES_PYTHON`. `uv venv -p 3.10 <dir> && uv pip install -p <dir>/bin/python kokoro-onnx soundfile` (156 MB, about 1s with a warm uv cache).
- **Surprise 2 (root cause verified):** espeak-ng silently falls back to a baked-in CI path (`/Users/runner/work/espeakng-loader/...`) when its data path is too long. The scratchpad venv's data path was 170 chars and failed; a short path worked (`phonemize('hello world')` OK). Pinning `espeakng-loader` 0.2.1–0.2.3 or `kokoro-onnx` 0.4.9 did not help.
- **Decision:** the skill creates the venv at `explain-output/work/kvenv` in the target repo (data path about 105 chars here). Chose this over a global cache so no files land outside the target repo. Tradeoff: a very deeply nested target repo could still exceed the limit, so the skill checks the path length and falls back to a shorter location if needed.
- **Working command:** `HYPERFRAMES_PYTHON=<venv>/bin/python npx -y hyperframes tts "<text>" -o <beat>.wav --voice af_heart --json`. `--json` returns `durationSeconds`, so `ffprobe` is only a cross-check.
- **Measured:** output is 24 kHz mono pcm_s16le WAV. The three test sentences took 3.52s, 4.67s, and 5.01s. Latency was 16s on the first call (the model was already cached from an earlier run) and 8–9s per call after that, so a 15-beat script needs about 2–3 minutes of TTS. Model cache: `~/.cache/hyperframes/tts`, 338 MB.
- **Unverified (needs a human ear):** pronunciation of code tokens. `explain-output/work/tts/b.wav` says "SKILL.md and graph.json" literally, and `c.wav` spells them out ("skill dot M D", "graph dot jason"). Until the user listens, the skill spells identifiers phonetically in narration.

## 2026-09-28 — Ticket 0003 (U3): SKILL.md skeleton, Inspect, accuracy law

- **Discovery:** graphify's Step 4 writes `graph.json` without community names. Nodes carry `label`, `community` (an int), and `source_file`. The names from Step 5 go only to `graphify-out/.graphify_labels.json`. So the skill copies both files into `work/`, and the label check (U5) must accept cluster titles from `.graphify_labels.json` and node labels from `graph.json`.
- **Decision:** reuse an existing graph only when its `built_at_commit` matches `HEAD`. Otherwise rebuild. Chose this over always rebuilding, since graphify's semantic pass costs subagent time.
- **Decision:** the media check (KTD9) is written generically. The skill checks detect output for video or audio and writes `.graphifyignore`, so it isn't specific to this repo.
- **Decision:** there's no `--format` option in M1 (landscape only), and `--voice` is the only flag.
- The Plan, Build, and Deliver sections are empty headers until U4–U6.

## 2026-09-28 — Ticket 0004 (U4): Plan step

- **Decision:** the beat format is one line per beat, `beat | narration | on-screen cue | claims ids`, so the script, the timeline, and the claims table share beat ids like `2.2`.
- **Decision (default values):** 0.4s between beats, 0.8s lead-in, and 1.0s tail per chapter. The chapter audio is resampled to 48 kHz (per KTD6) when the narration track is built.
- **Decision:** the narration spells identifiers phonetically ("graph dot json"), while the screen and `claims.md` keep the exact spelling. This stays provisional until the user listens to the U2 samples.
- **Decision:** the venv falls back to `~/.cache/explain-kvenv` only when the in-repo path is too long (over about 150 chars) for espeak-ng. That's the one case where the skill writes outside the target repo, and the skill tells the user when it happens.

## 2026-09-28 — Ticket 0005 (U5): chapter visuals and the code map

- **Decision:** each chapter page exposes `seek(t)`, and cue times come from `work/timeline-<n>.json`. This makes brag-slim's "pure function of time" rule concrete, so any capture tool can drive the page.
- **Decision:** the map shows only edges `graph.json` actually has between shown nodes, capped to a few if busy. The god node is marked and gets the closing beat.
- **Decision:** the label check allows exactly three sources: `graph.json` labels, `.graphify_labels.json` community names, and the chapter title. Fixes always go from the graph to the SVG, never the reverse. Its output goes in `work/label-check.txt` so U7's reviewer can see it.
- **Decision (look):** calm talk-style visuals, not brag's trailer energy. Brag's 0.3s-per-word reading rule is kept.

## 2026-09-28 — Ticket 0006 (U6): check, reviewer gate, render, join, deliver

- **Decision:** the reviewer gets only paths (`claims.md`, the repo root, `work/graph.json`, `work/.graphify_labels.json`), never the script or my reasoning. It marks each row supported, unsupported, or missing source, and also flags claims that are sourced but misleading. Every re-run uses a fresh subagent.
- **Decision:** a fixed ffmpeg encode line (libx264 yuv420p 30fps 1920x1080, AAC 48 kHz stereo 192k) is written into the skill, so the concat demuxer can join with `-c copy` (KTD6).
- **Decision:** the default poster is the finished code map with the god node highlighted.
- **Fix during the coherence pass:** `script.md` and `claims.md` are now written directly to the output folder rather than copied there at the end, and the chapter narration file `work/audio/chapter-<n>.wav` is named where it's built.

## 2026-09-28 — Ticket 0007 (U7): install and run M1 on this repo

- **Installed:** `~/.claude/skills/explain` symlinks to `skills/explain` (approved in 0001).
- **Result:** `explain-output/explain.mp4` is 103.25s (chapter 1 is 41.7s, chapter 2 is 61.5s), 1920x1080 at 30fps with H.264 and AAC 48 kHz, and 3096 frames. The poster in frame 0 matches `explain.jpg` (SSIM 0.989). The frame count and duration match the pre-poster `joined.mp4`.
- **Deviation:** the video is about 103s against the ~90s target. The script has 13 beats and all 22 claims made the cut. Tightening chapter 1 (1.4 is 10.7s) is the obvious lever if the user wants 90s.
- **Graph:** 153 nodes, 212 edges, 10 communities, built at `49163d9`. graphify's health check reported **11 dangling-endpoint edges**. It's non-fatal. I checked: of the 18 extraction edges with a missing endpoint (11 dangling plus 7 external), 7 touch a map node. They are `analyze_music_cues.py`'s imports of external libraries (argparse, json, math, pathlib, typing, librosa, numpy). They aren't in `graph.json`, so they don't affect any drawn edge or any counted degree. (An earlier draft of this note said none touched the map. That was unchecked and wrong.)
- **`.graphifyignore` extended:** detect found **265 audio files** (mp3/ogg/wav, which detect files under `video`), the 10 per-track music-cue data files, `plans/`, and `skills/brag/slim.md` (a byte-identical copy of brag-slim). After exclusion, detect found 20 files (7 code, 13 docs). Extraction used 2 parallel subagents (about 243k tokens in total).
- **Decision (community names):** graphify's Step 5 has the running model name the communities. That means cluster titles are graphify output the model wrote, not something extracted from the repo. The claims cite them to `.graphify_labels.json`, and the video presents them as "clusters" rather than as the repo's own terms.
- **Map:** 6 of 10 communities, the top 3 nodes of each by degree, and the 11 real edges among them. The label check passed 24 of 24, and a negative test (a paraphrased label) was caught.
- **Reviewer gate took 3 rounds.**
  - Round 1: C7 cited the wrong line (brag-slim `:10`, should be `:8`). C22 was flagged as misleading: "busiest node" was `analyze_track()` (12), but graphify's god ranking skips file nodes, and `analyze_music_cues.py` (19) and `check-docs.mjs` (13) are busier. The claim was reworded to "not counting whole files", and beat 2.8 was re-voiced.
  - Round 2: C20's line numbers were stale because I had edited `skills/explain/SKILL.md` mid-run. The "made this video" clause was also unsourced. Both were fixed.
  - Round 3: 22 of 22 supported.
- **Capture:** a zero-dependency CDP driver (`work/capture.mjs`) using Node 22's built-in `WebSocket` and the installed Chrome. 3097 frames took about 3 minutes, with both chapters in parallel.
- **Bug found and fixed:** the first poster bake (`-loop 1` with `-r 30`) added a frame. A single non-looped image silently skipped the overlay. The working command (`-loop 1 -framerate 30` with `shortest=1` and `-fps_mode passthrough`) now lives in the skill.
- **SKILL.md fixes from this run:** audio is listed under `video` in detect; skip verbatim copies; god nodes skip file nodes, so count degree yourself; three-layer map with gutter-routed edges; the zero-dependency capture tip; don't edit the repo between claims and review; the verified poster-bake command.
- **Open question for the user:** listen to `explain.mp4` for pronunciation ("analyze music cues dot pie", "Opus five point five", "Kokoro") and pacing. None of it has been checked by ear. The U2 samples are in the session scratchpad and weren't kept in the repo.

## 2026-09-28 — Moved to a standalone repo as /cribs

- **Decision (user):** make it a standalone repo instead of a brag fork, named `cribs`, with the command renamed to `/cribs`. It starts with fresh history, and the per-ticket history stays on the brag fork's `feat/explain` branch.
- **Changes on the move:** `name: cribs`, a `/cribs` trigger, and `cribs-output/`, `cribs.mp4`, `cribs.jpg`, `~/.cache/cribs-kvenv`. The example claims row that cited brag-slim is now plainly illustrative (`src/render.ts:42`). "the way brag-slim reuses them" became "so the video can reuse them".
- **Licensing:** MIT, carrying the upstream copyright notice in LICENSE, since the skill adapts brag-slim's structure. No brag music or SFX assets were brought over, so the unverified ende.app music license question doesn't apply here.
- **Not carried over:** brag's `.graphifyignore` (it was specific to that repo; the skill writes one per target repo as needed). There is no validation gate yet. See the follow-ups.

## 2026-09-28 — Repo scaffold (TerMinal template) tailored for cribs

- **Removed** `.gitlab/`: GitHub-only repo; the MR template only mirrored the PR template. Dropped the GitLab section of `docs/runbooks/branch-protection.md` too.
- **Replaced** the template's bun CI (would fail on every push: no package.json, lockfile, or tests) with `scripts/check.sh`, which checks SKILL.md frontmatter (`name` matches its folder, `description` non-empty) and relative Markdown links. CI job keeps the name `quality` so the branch-protection runbook stays correct. Verified it fails on a planted bad skill and a broken link.
- **Filled** placeholders in `CLAUDE.md` (header, [9], [11], [12]) and `docs/architecture.md`. Kept the template's generic TerMinal workflow sections unchanged.
- **Follow-up:** the generic TerMinal sections of CLAUDE.md are long (~14KB); trim them if they prove noisy in sessions.
