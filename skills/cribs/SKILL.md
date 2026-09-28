---
name: cribs
description: Turn a code repository into a narrated explainer video that walks a newcomer through what the project is and how its code is laid out, with every claim traced to a file and line. One file, no bundled assets. Use when someone says "/cribs", "give me a cribs tour of this repo", "explain this repo in a video", "make an explainer video", or "walk me through this codebase as a video".
---

# /cribs

MTV Cribs for a codebase: a guided tour of the house, where every claim is sourced. You make a narrated explainer video of a code repository, the kind a senior engineer would record to onboard a newcomer. You write the script, voice it, draw the visuals to the voice, and render, using the tools already on the machine.

Its biggest risk is being wrong, not being boring. A slick video that names a function that doesn't exist is worse than no video. Every claim you show or say comes from the code, the project's own docs, or the knowledge graph, and you can point to where.

Usage: `/cribs [options]`, run from the repo root. Options (flags or plain language):

| Option | Default |
|---|---|
| `--voice <kokoro voice>` | `af_heart` (run `npx hyperframes tts --list` for others) |

The video is landscape 1920×1080 at 30fps. It has two chapters and runs about 90 seconds:

1. **What it is:** what the repo does, who it's for, and why it's useful.
2. **Code map:** a map of the codebase, drawn from its knowledge graph and revealed cluster by cluster as the narration names each one.

Write the deliverables to `cribs-output/` in the repo root (timestamped `cribs-output-YYYY-MM-DD-HHmmss/` if it already exists). `script.md` and `claims.md` live there from the start, next to the video, so anyone can check what it says against the code. Keep every intermediate file (graph copy, audio, timelines, chapter pages, frames, stills, review) in a `work/` subfolder inside it.

## Accuracy law

Every claim about the code, on screen or in the narration, gets a row in `claims.md` before it goes into the video. For example:

| id | claim (as shown or spoken) | chapter.beat | source |
|---|---|---|---|
| C1 | Renders each frame as a pure function of time | 1.3 | `src/render.ts:42` |
| C2 | Code map cluster "Docs Site" | 2.2 | `graph.json` community 3, label from `.graphify_labels.json` |

- A **source** is a `file:line` (or `file:start-end`) in the repo, or a `graph.json` node id or community id. `GRAPH_REPORT.md` is for getting oriented and is never a source.
- Quote identifiers exactly as they appear in the source. Never make up a function name, a call path, a count, or a behavior. If you can't find a source, cut the claim.
- Framing that makes no claim about the code ("Let's take a look.") needs no row.

## 1. Inspect

### Read the project

Read the README, the manifest (`package.json`, `pyproject.toml`, `Cargo.toml`, …), the entry points, and any docs that say what the project is for. Note the project's own identity, meaning its exact colors and fonts if it has a UI or a site, so the video can reuse them.

### Build the knowledge graph

The code map comes from the `graphify` skill, not from your guess at the architecture. Read `~/.claude/skills/graphify/SKILL.md` and follow it on the repo root, with these rules:

- **Reuse a current graph.** If `graphify-out/graph.json` exists and its `built_at_commit` matches `git rev-parse HEAD`, use it as is. Otherwise build it.
- **Keep media out.** After graphify's detect step, check its output (`graphify-out/.graphify_detect.json`) for video or audio files (detect lists audio such as `.mp3`, `.ogg` and `.wav` under `video`). If there are any, don't transcribe them: write or extend a `.graphifyignore` in the repo root (same syntax as `.gitignore`) to exclude them, re-run detect, and tell the user in one line that you did. Use `.graphifyignore` rather than `.gitignore`, so git keeps tracking the files.
- **Skip verbatim copies.** If a file is a byte-for-byte copy of another (a bundled mirror of a skill, say), add the copy to `.graphifyignore` too, or the map gets duplicate nodes.
- **Get the first run right.** graphify refuses to write a `graph.json` smaller than the existing one, so a bad run can only be redone with `--force`. Check the detected file list before extraction.
- **Label the communities** (graphify's Step 5), so `graphify-out/.graphify_labels.json` exists. Those names become the map's cluster titles.

Copy `graph.json` and `.graphify_labels.json` into `work/`. From here on the copies in `work/` are the source of truth for the map.

### Answer the chapter questions

Before planning, answer each of these with a source (a `file:line`, or a node or community id):

- **What is it** (one sentence)? **Who is it for**, and what does it do for them? **Why is it useful**, meaning what can someone do with it that they couldn't easily do without it?
- **What are the main parts?** Pick 4–6 of graphify's communities to show, and for each one its 2–4 highest-degree nodes. Merge tiny communities or drop isolated nodes if the map gets noisy, but only with names that already exist in `graph.json` or `.graphify_labels.json`.
- **Which part holds the others together?** graphify's god nodes (its most-connected nodes) usually answer this. Its ranking skips whole-file nodes, so a file can have more connections than the top god node. Count degree in `graph.json` yourself, and word the claim to match what you counted ("not counting whole files, the most connected node is …").

Start `claims.md` with these answers.

## 2. Plan

The narration comes first, and the visuals are timed to it. Write the script, voice it one beat at a time, measure every beat, and only then build the visuals.

### Write `script.md`

Break each chapter into numbered **beats**. A beat is one or two spoken sentences plus what's on screen while they're spoken:

```
## Chapter 2: Code map

2.1 | "Here's how the code fits together." | empty canvas, title "Code map" | —
2.2 | "The skills folder is the product. ..." | cluster "Skill Workflow" draws in with its nodes | C4, C5
```

The format is `beat | narration | on-screen cue | claims ids`. Every beat that states something about the code lists the `claims.md` rows it relies on.

**Target length:** about 90 seconds. Chapter 1 is about 35s in 4–6 beats. Chapter 2 is about 55s: one intro beat, one beat per cluster, and one closing beat that names the god node. These are planning targets. The measured audio sets the real length.

### Narration laws

- **Spoken, not written.** Write short, plain sentences a person would say out loud. No bullet-list cadence and no parentheses.
- **Say identifiers so they sound right.** The voice reads text literally. Spell file names and code tokens the way a person says them ("skill dot M D", "graph dot json"), and keep the exact spelling on screen. The claims table cites the exact spelling.
- **One idea per beat.** Each beat gets one on-screen change. If a beat needs two changes, split it.
- **Nothing unsourced.** If a sentence makes a claim with no row in `claims.md`, add the row or cut the sentence.

### Voice it

The voice is Kokoro, run through `npx hyperframes tts`. That command needs a Python with `kokoro-onnx` and `soundfile` installed, so set up a venv inside `work/` once per run:

```bash
uv venv -p 3.10 work/kvenv && uv pip install -p work/kvenv/bin/python kokoro-onnx soundfile
export HYPERFRAMES_PYTHON="$PWD/work/kvenv/bin/python"
```

espeak-ng, which Kokoro uses for pronunciation, silently falls back to a nonexistent build path when its data path is too long. The failure reads `Error processing file '/Users/runner/work/espeakng-loader/...'`. Check the length of `work/kvenv/lib/python3.10/site-packages/espeakng_loader/espeak-ng-data` as an absolute path. If it's over about 150 characters, put the venv at a shorter path outside the repo (for example `~/.cache/cribs-kvenv`) and tell the user. If `uv` is missing, use `python3 -m venv` and `pip` the same way.

Then synthesize **one WAV per beat**:

```bash
npx -y hyperframes tts "<narration>" -o work/audio/2.2.wav --voice af_heart --json
```

`--json` prints `durationSeconds`, so record it for every beat. Each call takes several seconds, and the first run downloads about 340 MB of model weights. Output is 24 kHz mono WAV.

### Build the timeline

For each chapter, write `work/timeline-<n>.json`: every beat's start time and duration, with a gap of 0.4s between beats plus 0.8s of silence at the start and 1.0s at the end of the chapter. Beat start times are the cue points for the visuals. Build the chapter's narration track, `work/audio/chapter-<n>.wav`, by concatenating the beats with that silence (ffmpeg `adelay` or `apad`, or pre-made silent WAVs, at 48 kHz), and check that its length matches the timeline.

If a beat reads badly, whether rushed, mispronounced, or too long, rewrite it and re-synthesize that beat only. Then rebuild that chapter's timeline.

## 3. Build, check, render

Build each chapter as its own HTML page, `work/chapters/<n>.html`, drawn in a browser. Every frame is a pure function of time: the page exposes a `seek(t)` that sets everything for time `t` in seconds, reading cue times from that chapter's timeline, with no timers, no CSS animations left running, and no randomness. Wait for fonts and images to load before capturing each frame.

### Look

Calm and legible, like a good conference talk, not a launch trailer. Use one type family for text and one monospace family for code, dark or light to suit the project, and the project's own colors as accents if it has them. Code identifiers always go in the monospace face, spelled exactly. Keep motion purposeful: things draw in when the narration reaches them and then stay put.

Any text the viewer should read stays on screen, fully settled, for at least 0.3s per word. Each chapter opens on a title card (for example "1 · What it is") that settles during the lead-in silence.

### Chapter 1: What it is

One beat, one change. Typical cues are the project name and a one-line description, then who it's for, then the problem it removes, then a glimpse of the real thing: a real snippet of its README, a real command, or its real UI or site if it has one. Reuse the project's real assets and copy, not paraphrases. Anything shown is quoted from a file, and its `claims.md` row cites that file and line.

### Chapter 2: The code map

The map is an inline SVG with no graph library, built only from `work/graph.json` and `work/.graphify_labels.json`.

- **Content.** Each cluster is one of the communities you picked in Inspect, titled with its name from `.graphify_labels.json`. Its nodes are its 2–4 highest-degree nodes, labeled with their `label` from `graph.json` exactly as written, never shortened or reworded. Show the edges between the shown nodes that `graph.json` actually has, and at most a few of them if the map gets busy. Mark the god node so it stands out.
- **Layout.** Compute positions once and write them into the page: clusters on a loose grid or ring, each cluster's nodes packed inside a rounded region, and label boxes that never overlap. Leave room for the longest label at the video's font size, and wrap long labels at spaces so the lines rejoin to the exact label. Draw in three layers (panels, then edges, then nodes) so links between clusters aren't hidden under the panels, and route them through the gaps between panels so they never cross a title.
- **Reveal.** At each cluster's beat start, its region fades in, then its nodes draw in one by one over about a second, then its edges draw. Earlier clusters dim a little so the one being narrated leads. The closing beat brings everything back to full strength and highlights the god node and its edges.

### Check the map labels

Before any render, write a small script in `work/` that pulls every text label out of chapter 2's SVG and checks it. Each label must equal a `label` in `work/graph.json`, or a community name in `work/.graphify_labels.json`, or the chapter title. Any label that fails gets fixed from the graph, never the other way around. Run it and keep its output in `work/label-check.txt`.

### Check stills

Before rendering, capture a still at every beat start plus 1s, and one in the middle of each map reveal, into `work/stills/`. Look at every one of them. Fix overflow, overlapping labels, text too small to read at 1080p, and low contrast.

### Reviewer gate

Before the render, the claims get checked by someone who didn't write them. Spawn a subagent with **no prior context** and give it only the path to `claims.md`, the repo root, and the paths to `work/graph.json` and `work/.graphify_labels.json`. Don't give it the script, your reasoning, or a summary. Ask it to open every source and mark each row as follows in `work/review.md`:

- **supported:** the source says this, with the line it checked
- **unsupported:** the source doesn't say this, or says something different
- **missing source:** no source, or the source doesn't exist

Also ask it to flag any claim that is technically sourced but misleading as worded. Fix every row that isn't supported, by rewording the claim, fixing the source, or cutting it. Re-voice any beat whose narration changed, rebuild its timeline, and run the reviewer again, with fresh context each time, until every row is supported. Don't edit the repo between writing `claims.md` and the last review. If you must, re-check every line number the edit could have shifted.

### Render

Render each chapter separately. Capture its frames by driving `seek(t)` in headless Chrome (or whatever capture tool is on the machine; with no browser library installed, Node 22's built-in `WebSocket` can drive Chrome's DevTools protocol directly: set the viewport to 1920×1080, then `seek(t)` and `Page.captureScreenshot` per frame) for every frame from 0 to the timeline's end at 30fps, then encode with its narration track. Every chapter uses identical settings so the chapters can be joined without re-encoding:

```bash
ffmpeg -framerate 30 -i work/frames/<n>/%05d.png -i work/audio/chapter-<n>.wav \
  -c:v libx264 -pix_fmt yuv420p -r 30 -s 1920x1080 -c:a aac -ar 48000 -ac 2 -b:a 192k \
  -shortest work/chapters/<n>.mp4
```

Check each chapter with `ffprobe`: one video stream and one audio stream, and a duration that matches its timeline within a frame. Then join them with the concat demuxer (`-f concat -safe 0 -i work/concat.txt -c copy`) into `work/joined.mp4`. If a chapter needs a redo, re-render only that chapter and re-join.

## 4. Deliver

- **Poster:** pick the strongest *settled* frame. The finished code map with the god node highlighted is usually the one. Save it as `cribs.jpg` and bake it in as frame 0 of the joined video to make `cribs.mp4`, so every platform's thumbnail shows it. Replace frame 0 rather than adding a frame, so the duration and audio sync stay the same. Check with `ffprobe` that `cribs.mp4` has the same duration **and frame count** as `work/joined.mp4`. This command does it; the obvious variants either add a frame (`-r 30` with a looped image) or silently skip the overlay (a single, non-looped image):

  ```bash
  ffmpeg -i work/joined.mp4 -loop 1 -framerate 30 -i cribs.jpg \
    -filter_complex "[1:v]format=yuv420p,scale=1920:1080[p];[0:v][p]overlay=enable='eq(n\,0)':shortest=1[v]" \
    -map "[v]" -map 0:a -c:v libx264 -pix_fmt yuv420p -fps_mode passthrough -c:a copy -movflags +faststart cribs.mp4
  ```
- **`share-copy.txt`:** 1–3 sentences, postable as-is, specific to this project. Say what the viewer will understand after watching. No "excited to share."
- **Tell the user** where the video is, its length, how many claims it makes and that a fresh reviewer checked all of them, and offer to redo a chapter or re-voice a beat.
