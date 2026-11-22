# macOS header double-click smoke

Build `MacHeaderDoubleClickSmoke.dproj` for `OSXARM64` and run the executable
inside a macOS app bundle with `CFBundleExecutable=MacHeaderDoubleClickSmoke`.
Pass a writable log path as the first argument. The test posts two double-clicks
to empty header space and requires native zoom followed by restore. It writes
`DOUBLE CLICK ZOOM RESTORE PASS` and exits with code 0 on success.

The test opens a visible window and must run in a logged-in macOS session.
