# Changelog

## Unreleased

### Changed

- Draw by holding either Command key and moving the pointer, without clicking or pressing the trackpad. Releasing Command ends the stroke; movement and clicks without Command do not draw.
- Replace the View/Edit switch with an automatic Cursor mode/Paint mode indicator and updated accessibility guidance.
- Keep color selection, Clear, Save & Clear, and Load available in Cursor mode; pause drawing while file dialogs or error alerts are open.
- End strokes when leaving the canvas or losing window/app focus, preventing connecting lines across gaps. Handle Command changes even when toolbar controls have keyboard focus.
- Remove the core session's View/Edit mode restriction while retaining drawing validation and the existing JSON format.
- Update README drawing instructions and expand native canvas and core tests for the new interaction.
