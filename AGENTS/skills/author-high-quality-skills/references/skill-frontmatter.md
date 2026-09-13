# Skill Frontmatter

Every skill root file must start with YAML frontmatter:

```yaml
---
name: skill-name
description: Use when [specific triggering conditions]
---
```

Rules:

- `name` uses lowercase letters, digits, and hyphens only
- keep the folder name equal to `name`
- `description` describes when to use the skill, not what it does
- start the description with `Use when`
- include concrete triggers, symptoms, or situations
- do not summarize the workflow in the description

Good:

```yaml
description: Use when creating or revising a local skill and you need progressive disclosure with explicit verification.
```

Bad:

```yaml
description: Creates a skill by asking questions, writing files, and validating them.
```
