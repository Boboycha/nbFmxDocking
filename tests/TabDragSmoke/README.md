# macOS tab drag smoke

Build `TabDragSmoke.dproj` for `OSXARM64` and run the executable inside a
macOS app bundle with `CFBundleExecutable=TabDragSmoke`. Pass a writable log
path as the first argument. An optional second argument is an FMX style file.

The test opens a visible window and exercises tab drag callbacks. It writes
`TAB DRAG PASS` and exits with code 0 on success; a logged-in macOS session is
required.
