# macOS title bar smoke

Build `MacTitleBarSmoke.dproj` for `OSXARM64` and package the executable in a
regular macOS app bundle (`CFBundleExecutable=MacTitleBarSmoke`). The test uses
the real `TnbWindowTitleBar` component and does not access application data.

Run the app normally to verify that all three native window buttons are outside
the FMX client rectangle before and after resizing, and that a native mouse
click still reaches an ordinary FMX button. It prints `PASS` and exits.

Run with `-legacy-overlay` to reproduce the old full-size-content/background-drag
settings. The geometry check must fail because the native buttons overlap the
FMX client rectangle. View coordinates are converted into a common ancestor
with AppKit's current `convertRect:fromView:` API.

Run with `-manual` to keep the test open after its automated checks. Check that
traffic lights are aligned in the native title strip, dragging that strip moves
the window, dragging empty client space does not move it, and the client button
still responds. Standard close/minimize/zoom and resize remain AppKit behavior.
Run with `-unified` to test the opt-in shared-header mode. Native controls must
be centered within the header's reserved leading area, a client button and a
child header button must both receive native clicks, and alignment must survive
resize. `-manual -unified` keeps that layout open for native header dragging,
body non-dragging, native system-button actions and visual acceptance.

Hosts opt in with `MacUnifiedTitleBar=True`, provide a full-width top
`TitleControl`, and reserve `MacSystemButtonsInset` at its leading edge before
tabs. Window dragging is installed only on the title/tab-bar background;
child controls retain their handlers. Existing mouse/resize/activation handlers
are restored on removal, and pending callbacks are removed on teardown.
The default remains the separate standard native title strip.
The unified test also posts a down/up pair to empty header space to exercise
AppKit's native drag entry, then verifies the header is released and a new
client click still works. Physical drag distance and system-button actions
remain manual acceptance checks. Native button positioning is synchronized
with the observed window's update notifications; observers and deferred
callbacks are removed when the title-bar component is detached or destroyed.

Run with `-unified -fullscreen` to verify native fullscreen button ownership.
The test enters a real fullscreen Space, temporarily probes native button
frames, calls the component's Apply method, and requires that AppKit-owned
frames remain untouched. It restores the probes, exits fullscreen and checks
that normal unified-header alignment returns. The old implementation fails
this check because it repositions fullscreen buttons into the FMX header.
Hover the physical pointer at the screen's top edge manually to verify that
the system's revealed fullscreen controls remain visible and clickable.
