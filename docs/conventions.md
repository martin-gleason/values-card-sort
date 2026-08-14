# Conventions (vendored, pinned)

Pinned copy of the universal working conventions. This file is the project-local source of truth; do not reach into any parent workspace.

## Structural — the work chunks (the only axis with IDs)

- **Feature** `F<N>` — a deliverable unit of user value. Decomposes into Tasks.
- **Task** `F<N>-T<M>` — an implementation step inside a feature.
- **Chore** `C<N>` — an operational task the **human** performs. The parallel track to Features.
- **Retrofit** `F<N>b`, `F<N>c` — a second pass on an already-shipped feature.

## Lifecycle — metadata, not a container

- **Phase** — what *stage* a unit is in (design / build / test / deploy). A tag, no structural ID. A feature in build phase is still `F3`, never "Phase 3."

## Authorization

- **Gate** — a boundary crossed only with the maintainer's explicit go-ahead. Phases are separated by gates; features are separated by gates.

## Merge

- **PR** — the unit of change merged to `main`. One or more Tasks on a single feature branch.
- Conventional commits: `<type>(<id>): <description>` (e.g. `feat(F2-T1): sort queue and pile assignment`).
- Branch naming: `<feature-id>/<slug>` (e.g. `f2/sort-phase`).
- Rebase-and-merge — no squash, no merge commits — so every commit survives for audit.

## Enforcement surface

Rules an agent can drift past belong in deterministic checks, not prose: CI (`.github/workflows/ci.yml`) runs build + tests + deck fidelity on every PR; branch protection on `main` requires green CI and a review.

-----
August 14, 2026

#AI/Claude
