# Window title-bar hit-test regression

This Windows console probe creates a hidden FMX form with `TnbWindowTitleBar`
and sends native `WM_NCHITTEST` messages to its actual HWND. It uses no
application profile or network services.

Run from this directory after loading the installed Delphi `rsvars.bat`:

```bat
mkdir bin
dcc64 -B -Q -$R+ -$Q+ -U"%BDS%\lib\Win64\release;..\..\src" -NS"System;System.Win;Winapi;FMX;Data;Xml" -Ebin -N0bin WindowHitTestSmoke.dpr
bin\WindowHitTestSmoke.exe
```

The probe moves the hidden window into all four screen-coordinate quadrants.
It dispatches `WM_DPICHANGED` at 96, 144 and 192 DPI to exercise FMX's actual
per-window scene scale. At each position/scale, the body must return
`HTCLIENT` and the bottom edge must still return `HTBOTTOM`.

The old unsigned coordinate extraction returns `HTRIGHT`, `HTBOTTOM`, or
`HTBOTTOMRIGHT` for clicks in the body when a screen coordinate is negative.
Using the primary display's scale also misclassifies body points when the
window scene has a different DPI.

Synthetic DPI changes cover coordinate routing; a visible consumer still needs
acceptance by moving it between physical monitors with different scaling.
