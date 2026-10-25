# Unified Loading V1

`OrLoadingThemeData` is the single visual entry point for the OR-APP loading
family. Change its immutable `OrLoadingTokens` to adjust palette, bar count,
spacing, heights, motion duration and surface padding without changing a page.

Use `OrLoadingSurface` for full-screen and section operations, and
`OrLoadingInline` when an operation must preserve a button or row's scope.
`OrLoadingIndicator` is available for purpose-built surfaces. Its animation is
purely visual: data readiness must always come from the owning operation.

The V1 font readiness service loads the bundled KleeOne faces once and offers a
retryable readiness state. It has no time-based delay. Technical numeric UI can
continue to opt into ShareTechMono explicitly.
