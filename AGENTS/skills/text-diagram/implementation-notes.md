# Implementation Notes

## 2026-06-15

- Reframed the skill from "diagram generator" to "reading map artifact" so it can optimize human reading speed rather than forcing Mermaid as the whole deliverable.
- Removed contradictory output expectations by making the Mermaid diagram primary when helpful, but allowing supporting routing sections around it.
- Chose to explicitly support messy raw text such as transcripts, meeting notes, and mixed-structure documents because those are the highest-value productivity cases.
- Preserved Mermaid as the main visual layer, but allowed "no diagram" or a simpler outline-first result when the source is too unstructured to diagram honestly.
- Relaxed the universal style rules so non-flowchart Mermaid types are not forced into edge-label or optional-edge conventions they do not support cleanly.
- Added an explicit written-result layer before the map so a human can read the distilled output first, then approach the raw text with attention cues already loaded.
- Clarified that the pre-read output is more like a lesson preview or advance organizer: it should give the reader a rough map of structure and thought flow before the raw-content journey starts.
- Removed the misleading idea that the raw text is part of the generated output sequence; the actual workflow is source text on one side and the guide artifact on the other.
- Added an explicit artifact template so agents have a fixed output scaffold and do not drift into uneven or incomplete guides.
- Extracted the artifact template into its own file so the main skill entry stays focused on purpose, process, and routing.
