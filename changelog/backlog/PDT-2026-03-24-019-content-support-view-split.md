# PDT-2026-03-24-019 Content Support View Split

## Status

- Current status: `awaiting_user_review`
- Priority: P1
- Target release version: `0.1.20`
- Target feature slug: `content-support-view-split`

## User Request

Keep going on the refactor while full Xcode installs, using safe UI decomposition work that can be verified with `swift build`.

## Constraints

- Preserve behavior; this pass is about file boundaries, not functional redesign.
- Keep keyboard, sheet, preview, inspector, and inline-grid support behavior unchanged.
- Maintain a clean commit boundary with updated repo tracking and release metadata.

## Implementation Intent

- Split the oversized `ContentViewSupportViews.swift` file into focused support files.
- Separate inspector views, row/card views, inline section views, and preview/keyboard helper views.
- Leave references in `ContentView` and `ContentViewBrowserSections` unchanged apart from file organization.

## Test Conditions

- `swift build` succeeds after the split.
- The top-level coordinator and browser/review sections continue compiling against the moved types.
- No support view definitions remain in a single monolithic file.

## Success Criteria

- Support views are grouped by responsibility in separate files.
- The support-view layer is easier to navigate without changing runtime behavior.
