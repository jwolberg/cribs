# Architecture

> Evergreen system overview. **Edit it in place** (ADRs, by contrast, are append-only) and keep
> it matching the shipped skill. Headings carry `[N]` anchors (`ARCH#2`).

anchor: ARCH

## [1] Overview

cribs is a Claude Code skill, `/cribs`, that turns a code repository into a
narrated explainer video (1920×1080, 30fps, about 90s in M1) for someone new
to the code. Its defining constraint is accuracy: every claim the video shows
or says is recorded in `claims.md` with a `file:line` or knowledge-graph
source, and a fresh-context reviewer checks every row before anything renders.

## [2] Components

There is no application code. The product is a single instruction file that
Claude follows at run time, using tools already installed on the machine.

### [2.1] The skill: `skills/cribs/SKILL.md`
The whole product. It covers the options, the accuracy law, and the four phases
(Inspect, Plan, Build/check/render, Deliver). Install it by symlinking the folder
into `~/.claude/skills/cribs`. Per the frontmatter, it is one file with no
bundled assets, so anything the run needs (label-check script, chapter pages,
Chrome driver) gets written fresh into the target repo's `cribs-output/work/`.

### [2.2] Plans: `plans/m1/`
The M1 build plan, handoff, and the running implementation notes. These notes
record the decisions and surprises behind SKILL.md's rules, for example the
espeak-ng path-length limit and why labels come from `.graphify_labels.json`.

### [2.3] Repo tooling
`scripts/check.sh` is the verification gate, and CI (`.github/workflows/ci.yml`,
job `quality`) runs the same script. `docs/` holds this file, ADRs, runbooks,
learnings, and the TerMinal workflow docs.

## [3] Data flow

A `/cribs` run in a target repo:

1. **Inspect:** read the README, manifest and entry points. Build or reuse the
   graphify knowledge graph, which is reused only when `built_at_commit`
   matches `HEAD`. Copy `graph.json` and `.graphify_labels.json` into `work/`,
   and start `claims.md`.
2. **Plan:** write `script.md` beat by beat, synthesize one Kokoro WAV per beat
   (`npx hyperframes tts`, per-run uv venv), and build per-chapter timelines
   from the measured durations.
3. **Build, check, render:** each chapter is an HTML page with a pure `seek(t)`.
   Then come three gates: a map label check against the graph, visual stills,
   and a fresh-context claims reviewer. After that, render the frames in
   headless Chrome, encode each chapter with ffmpeg, and concat.
4. **Deliver:** bake the poster into frame 0 to produce `cribs.mp4`, plus
   `cribs.jpg`, `script.md`, `claims.md` and `share-copy.txt` in
   `cribs-output/`.

## [4] Key decisions

No project ADRs yet beyond ADR-0001 (recording decisions). The M1 decisions
live in `plans/m1/implementation-notes.md`. Promote any that should outlive M1
into `docs/decisions/`.

## [5] External dependencies & services

All of these run locally in the target repo. Nothing is hosted.

- **graphify skill** (`~/.claude/skills/graphify`): builds the knowledge graph
  used for the code map and as a claims source.
- **Hyperframes `tts` + Kokoro** (kokoro-onnx, via `npx`, about 340 MB of model
  weights cached in `~/.cache/hyperframes/tts`): narration.
- **uv + Python 3.10**: the per-run venv for Kokoro.
- **Google Chrome** (headless, driven over the DevTools protocol from Node 22):
  frame capture.
- **FFmpeg / ffprobe**: encoding, concat, poster bake, and duration checks.
- **Claude Code subagents**: graph extraction and the claims reviewer.

## [6] Conventions

- Changes to the skill are changes to prose. Keep SKILL.md's voice (plain,
  imperative, every rule tied to a reason) and don't bundle helper files next
  to it.
- The M1 target for dogfooding was the brag fork. Any repo works as a target,
  including this one.
