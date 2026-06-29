# Diagrams

Mermaid sources for the design docs. The files under [`src/`](src/) are the **single source
of truth** for every diagram in this repo. The build tool
([`../../scripts/build_docs.py`](../../scripts/build_docs.py)) injects each
`src/*.mermaid` file into the matching

```
<!-- START_GENERATED:docs/diagrams/src/<name>.mermaid -->
... (auto-filled) ...
<!-- END_GENERATED:docs/diagrams/src/<name>.mermaid -->
```

block across `README.md` and every `*.md` under `docs/` (README, HLD, LLD, ADRs, runbooks).
Edit the `.mermaid` file, run the build, and every copy updates — no hand-syncing.

| Source | What it shows |
|---|---|
| `architecture_at_a_glance.mermaid` | The system shape — components, boundaries, flows (vendor-agnostic). |
| `lifecycle.mermaid` | The lifecycle state machine: provision → operate → maintain → decommission. |

## Conventions

- One concept per diagram. If it needs a legend, it's two diagrams.
- Color load-bearing nodes consistently (e.g. red = the problem/constraint, green = the
  desired end state). Keep a stable palette across diagrams in the repo.
- Mermaid over ASCII art, always.

## Rendering

GitHub renders Mermaid in fenced ```` ```mermaid ```` blocks natively, so injected copies
display inline. Regenerate after editing a source:

```bash
python3 scripts/build_docs.py
```
