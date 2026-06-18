---
name: text-diagram
description: Use when a human needs to process raw text faster by identifying invariant content, skip-worthy filler, and a better-than-linear reading order.
argument-hint: "[text to analyze]"
allowed-tools: Read, Write, Bash
---

# Text-to-Diagram Reading Map

Turn raw text into a **reading map artifact** that helps a human decide:
- what to read first
- what can be skimmed
- what can be skipped
- what is unclear or structurally weak
- how the text's thought flow moves from one idea to the next

The generated artifact should be consumed in this order:
1. a short written result
2. the reading map

The Mermaid diagram is usually the primary visual view, but it is not the whole deliverable. The goal is to preload the reader's attention before they return to the source text.

Treat the output like a **lesson preview** or **advance organizer**:
- first give the reader the rough picture
- show the main structure and thought flow
- then let them continue through the raw content with that mental map already loaded

The workflow is side-by-side:
- raw text on the left
- guide artifact on the right

The raw text is not part of the generated output. The artifact exists to guide the live reading of the source.

## Core Principle

The artifact does **not** replace the text. It routes the reader through it.

Prioritize:
1. invariant information
2. dependencies between core ideas
3. action-relevant details
4. optional context and filler
5. the attention cues the reader should carry into the source
6. the rough structure and thought flow of the full piece

## Best-Fit Inputs

Use this skill for:
- articles, memos, specs, transcripts, notes, interviews
- meeting notes with decisions mixed into chatter
- long docs where the reader needs a fast path
- messy text that has useful content but weak structure

Do not force a diagram for:
- tiny text with no real structure
- text whose only value is exact wording
- content that is mostly table data or code

## Process

Follow these steps in order.

### Step 1: Segment the Text

Split the source into stable units in original order:
- headings or topical shifts
- claims
- definitions
- instructions
- decisions
- evidence
- elaboration or background
- open questions or ambiguity

Assign each unit a stable id: `§1`, `§2`, etc.

If the source is messy, create segments from paragraph or speaker-turn boundaries. Do not pretend the source is cleaner than it is.

### Step 2: Score for Reading Value

Score each unit from 1 to 5 based on how much it helps a human process the text efficiently.

| Score | Meaning | Reading guidance |
|---|---|---|
| 5 | Core invariant | Read early. Text fails without it. |
| 4 | Structural dependency | Read early. Organizes or constrains other parts. |
| 3 | Important support | Read if you need confidence or execution detail. |
| 2 | Useful context | Skim later if needed. |
| 1 | Low-yield filler | Skip unless the reader needs completeness. |

Rule of thumb:
- If removing it breaks the text's core meaning, score `4` or `5`.
- If it mostly adds texture, score `1` or `2`.

### Step 3: Identify the Reader's Fast Path

Before choosing a diagram, decide the smallest reading path that preserves the text's core value.

Build:
- a **preview model** of the overall structure and thought flow
- a **fast path** from the highest-yield units
- a **deep path** for fuller understanding
- a **skip list** for low-yield sections when appropriate
- an **attention list** for what the reader should actively watch for while rereading

### Step 4: Choose the Representation

Load `diagram-types.md` before choosing.

Pick the representation that best exposes structure:
- use Mermaid when relationships matter visually
- use a simpler reading order when structure is weak but still recoverable
- say "no honest diagram" if the source is too fragmented to map without inventing structure

Default to `flowchart TD` unless another Mermaid type clearly fits better.

### Step 5: Build the Reading Map

If using Mermaid:
- include core nodes scored `4` or `5`
- include score-`3` nodes only when they materially help understanding or action
- include score-`2` material only as optional detours when the chosen diagram type supports that cleanly

Node rules:
- keep labels concise
- prefer extractive phrasing from the text
- allow light normalization for clarity
- include one or more `§N` references per node

Edge rules:
- connect by dependency, support, contrast, sequence, or scope
- do not mirror original order unless order is the real structure
- use optional or dashed relationships only when the diagram type supports them cleanly

Complexity rules:
- max 12 visible nodes by default
- if there are too many important units, group them under a parent node
- if grouping would hide the real structure, prefer a simpler artifact over a dishonest diagram

### Step 6: Produce the Reading Guide

Always pair the map with a compact guide.

```markdown
| Order | Node / Unit | § Ref | What to read | Why |
|---|---|---|---|---|
| [1] | Main decision | §4 | Paragraphs 6-7 | Highest-yield point |
```

Also include:
- `Written result`: the distilled understanding the human should read first
- `Fast path`: minimum useful reading order
- `Deep path`: fast path plus supporting context
- `Skippable`: low-yield sections worth deferring or omitting
- `Ambiguities`: places where the source is structurally unclear, contradictory, or underspecified
- `Watch for`: the concepts, tensions, or details the human should keep active in memory while rereading

## Written Result Rules

The written result comes **before** the diagram.

It should be short and high-signal:
- 3 to 7 bullets
- each bullet states a durable point, decision, dependency, or warning
- do not restate the whole text
- write for pre-reading orientation, not for standalone completeness
- help the reader form a rough mental model before reading the raw content itself

Good written-result bullets tell the reader:
- what the text is really about
- what matters most
- what parts are likely to be noise
- what unresolved tension to notice while reading
- how the thought flow roughly progresses

## Output Format

Use the artifact template in `artifact-template.md` unless the user explicitly asks for another shape.

## Constraints

- Do not summarize the whole text paragraph-by-paragraph.
- Do not invent structure the source does not support.
- Do not flatten everything into chronology if dependency is the real shape.
- Do not force Mermaid if a truthful "too unstructured to diagram" result is better.
- Optimize for human reading speed and judgment, not diagram completeness.
- Make the written result useful enough that the reader can enter the raw text with the right mental highlights already loaded.
- Make the output feel like a lesson preview: enough structure to orient the reader, not so much detail that it replaces the journey through the source.

## Sub-files

Load `artifact-template.md` before writing the final artifact.
Load `diagram-types.md` before choosing the representation.
