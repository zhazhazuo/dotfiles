# Artifact Template

Use this template unless the user explicitly asks for another output shape.

## Required Structure

Every output should follow this structure:

1. `Title`
2. `Source Shape`
3. `Written Result`
4. `Reading Map`
5. `Reading Guide`
6. `Reading Paths`
7. `Invariants`
8. `Ambiguities`

## Section Intent

- `Title`: short source label the human can recognize quickly
- `Source Shape`: what kind of raw text this is, how structured it is, and how the guide should be used
- `Written Result`: the pre-read lesson preview; gives the rough picture before the source is reread
- `Reading Map`: Mermaid diagram or an explicit statement that no honest diagram fits
- `Reading Guide`: row-by-row mapping from guide nodes to source sections
- `Reading Paths`: fast path, deep path, skippable material, and what to watch for
- `Invariants`: the most durable ideas that survive rereading
- `Ambiguities`: contradictions, missing links, weak transitions, or unresolved questions in the source

## Quality Rules

- Fill every section. If a section is weak, say why instead of omitting it.
- Keep the written result and invariants distinct.
- `Written Result` is for orientation before reading.
- `Invariants` is for what remains true after reading.
- `Ambiguities` must be concrete, not generic.
- `Reading Paths` must be actionable enough that a human can immediately start reading with the guide open.

## Template

````markdown
## Reading Map: [title or source label]

### Source Shape
- Type: [article / transcript / notes / spec / mixed]
- Structure quality: [strong / moderate / weak]
- Recommended use: [skim-first / decision support / study / action extraction]

### Written Result
- [durable point the reader should load first]
- [key dependency, decision, or warning]
- [rough thought-flow cue: where the text starts, turns, and lands]
- [what to watch for in the source]

### Reading Map
[Mermaid diagram, or a brief statement that no honest diagram fits]

### Reading Guide
| Order | Node / Unit | § Ref | What to read | Why |
|---|---|---|---|---|

### Reading Paths
- Fast path: [1] -> [2] -> [3]
- Deep path: Fast path + [...]
- Skippable: §2, §8, §11
- Watch for: [term, contradiction, dependency, open question]

### Invariants
[2-4 bullets covering only the most durable ideas]

### Ambiguities
- [structural gap, contradiction, or unresolved point]
````
