"""Screenshot the Connect IQ simulator's device screen.

PrintWindow with PW_RENDERFULLCONTENT after SetProcessDPIAware: CopyFromScreen
without DPI awareness comes out offset and grabs whatever is on top instead.
Deliberately does not send input - driving the simulator with synthetic
keystrokes types into whatever window the user is actually using.
"""
import ctypes, sys, time
from ctypes import wintypes
from PIL import Image

user32, gdi32 = ctypes.windll.user32, ctypes.windll.gdi32
user32.SetProcessDPIAware()

def find_window(prefix="CIQ Simulator"):
    out = []
    @ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HWND, wintypes.LPARAM)
    def cb(hwnd, _):
        n = user32.GetWindowTextLengthW(hwnd)
        if n:
            b = ctypes.create_unicode_buffer(n + 1)
            user32.GetWindowTextW(hwnd, b, n + 1)
            if b.value.startswith(prefix) and user32.IsWindowVisible(hwnd):
                out.append((hwnd, b.value))
        return True
    user32.EnumWindows(cb, 0)
    return out

RDW_INVALIDATE, RDW_UPDATENOW, RDW_ALLCHILDREN = 0x1, 0x100, 0x80

def grab(hwnd):
    # Force a repaint first. An occluded window keeps serving its last
    # painted frame, so without this you capture whatever the simulator
    # looked like before the app was pushed. Does NOT raise or focus the
    # window - the user may well be typing into something else.
    user32.RedrawWindow(hwnd, None, None,
                        RDW_INVALIDATE | RDW_UPDATENOW | RDW_ALLCHILDREN)
    time.sleep(0.4)
    r = wintypes.RECT()
    user32.GetWindowRect(hwnd, ctypes.byref(r))
    w, h = r.right - r.left, r.bottom - r.top
    hdc = user32.GetWindowDC(hwnd)
    mdc = gdi32.CreateCompatibleDC(hdc)
    bmp = gdi32.CreateCompatibleBitmap(hdc, w, h)
    gdi32.SelectObject(mdc, bmp)
    user32.PrintWindow(hwnd, mdc, 2)          # 2 = PW_RENDERFULLCONTENT
    class BI(ctypes.Structure):
        _fields_ = [("biSize", wintypes.DWORD), ("biWidth", wintypes.LONG),
                    ("biHeight", wintypes.LONG), ("biPlanes", wintypes.WORD),
                    ("biBitCount", wintypes.WORD), ("biCompression", wintypes.DWORD),
                    ("biSizeImage", wintypes.DWORD), ("biXPelsPerMeter", wintypes.LONG),
                    ("biYPelsPerMeter", wintypes.LONG), ("biClrUsed", wintypes.DWORD),
                    ("biClrImportant", wintypes.DWORD)]
    bi = BI(ctypes.sizeof(BI), w, -h, 1, 32, 0, 0, 0, 0, 0, 0)
    buf = ctypes.create_string_buffer(w * h * 4)
    gdi32.GetDIBits(mdc, bmp, 0, h, buf, ctypes.byref(bi), 0)
    gdi32.DeleteObject(bmp); gdi32.DeleteDC(mdc); user32.ReleaseDC(hwnd, hdc)
    return Image.frombuffer("RGBA", (w, h), buf, "raw", "BGRA", 0, 1).convert("RGB")

class POINT(ctypes.Structure):
    _fields_ = [("x", wintypes.LONG), ("y", wintypes.LONG)]

def screen_rect(hwnd):
    """Where the watch screen sits inside a window capture.

    The simulator draws device.png at the client origin 1:1, and
    simulator.json gives the screen's offset within that image. Deriving
    the client origin beats hardcoding: the menu bar is non-client area, so
    the offset is not simply the border width.
    """
    import json, os
    dev = os.path.expandvars(r"%APPDATA%\Garmin\ConnectIQ\Devices")
    import re
    # device id from the window title is unreliable; caller passes it
    raise NotImplementedError

def client_origin(hwnd):
    pt = POINT(0, 0)
    user32.ClientToScreen(hwnd, ctypes.byref(pt))
    r = wintypes.RECT()
    user32.GetWindowRect(hwnd, ctypes.byref(r))
    return pt.x - r.left, pt.y - r.top

def grab_screen(hwnd, device="venux1"):
    """Window capture cropped to exactly the device's screen pixels."""
    import json, os
    sj = os.path.join(os.path.expandvars(r"%APPDATA%\Garmin\ConnectIQ\Devices"),
                      device, "simulator.json")
    loc = json.load(open(sj, encoding="utf-8"))["display"]["location"]
    ox, oy = client_origin(hwnd)
    img = grab(hwnd)
    x, y = ox + loc["x"], oy + loc["y"]
    return img.crop((x, y, x + loc["width"], y + loc["height"]))

if __name__ == "__main__":
    wins = find_window()
    if not wins:
        print("no simulator window found"); sys.exit(1)
    hwnd, title = wins[0]
    print("window:", title)
    img = grab(hwnd)
    img.save(sys.argv[1] if len(sys.argv) > 1 else "window.png")
    print("saved", img.size)
