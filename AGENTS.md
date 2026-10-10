# 4D Project — Global Instructions

## Pre-Work Requirement

Before writing or generating ANY code in this project, you MUST read the relevant instruction files in `.github/.instructions/`. These instructions contain project-specific conventions, patterns, and constraints that override general knowledge.

**Do NOT rely on general knowledge of 4D.** Always consult the instructions first — especially when creating new files, since `applyTo` patterns only trigger on existing files.

## Instruction Files Reference

| File | Scope | When to read |
|------|-------|--------------|
| `4d.instructions.md` | All `.4dm` files | **Always** — core 4D coding conventions |
| `4d.forms.instructions.md` | Forms (`*.4DForm`, form `*.4dm`) | Creating or editing forms, buttons, events, form classes |
| `4d.orda.instructions.md` | All `.4dm` files | Working with database queries, entities, selections |
| `4d.catalog.instructions.md` | Catalog (`*.4DCatalog`) | Creating or editing tables, fields, relations |
| `4d.aikit.instructions.md` | All `.4dm` files | Using AI/LLM features (OpenAI, chat completions) |
| `4d.errors.instructions.md` | All `.4dm` files | Debugging or interpreting 4D errors |
| `4d.test.instructions.md` | All `.4dm` files | Writing or running tests |
| `4d.localization.instructions.md` | `.xlf`, `.4dm`, localization files | Working with translations, XLIFF, localized strings |

## Skills Reference

| Skill | When to load |
|-------|--------------|
| `4dform` | Looking up 4D documentation for form objects, properties, or events; Sizing, positioning, aligning, or spacing controls in a `.4DForm` file |

## Workflow

1. **Identify** which instruction files are relevant to the task
2. **Read** those files before writing any code
3. **Follow** the patterns and conventions described
4. **Consult skills** when you need reference documentation or layout calculations

## Skills

Reusable 4D knowledge lives in the `.agents` submodule (`miyako/skills`, branch `dist`):

- Each skill is at `.agents/skills/<name>/SKILL.md`. Copilot, Codex and Claude Code discover them automatically.
- Read `.agents/AGENTS.md` first: it explains which skill to use for which 4D artifact
  (`.4DProject`, `.4DForm`, `.4DCatalog`, `.4DSettings`, `.4dm`, XLIFF …).
- Prefer the most specific skill over general knowledge of 4D.
- Never edit files under `.agents/`: they are overwritten by the weekly skills update.

## Setup

```sh
git submodule update --init .agents
```

If `.agents/` is empty, run the command above before doing anything else. `--recursive` is not needed.
Tools provisioned by the skills go to `tools/4dcatalog/`, `tools/4dform/`, `tools/4dlsp/`, `tools/4dlang/` and `tools/4dcli/`;
they are ignored by `.gitignore` and must not be committed.

## Instructions vs skills

- **Repository-specific rules** go in this file, or in `.github/instructions/*.instructions.md` with an
  `applyTo` glob when they only apply to some paths.
- **Reusable know-how** (4D language, forms, CSS, XLIFF, project settings …) goes to
  [miyako/skills](https://github.com/miyako/skills). Never copy a skill or its content into this repository;
  improve the skill there instead, and mention what you learnt to the user so it can be upstreamed.

## README

`README.md` is for developers. Never put Copilot model, mode, token or session content (usage tables,
model selection advice, session logs) in `README.md`.
