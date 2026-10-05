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

if __name__ == "__main__":
    wins = find_window()
    if not wins:
        print("no simulator window found"); sys.exit(1)
    hwnd, title = wins[0]
    print("window:", title)
    img = grab(hwnd)
    img.save(sys.argv[1] if len(sys.argv) > 1 else "window.png")
    print("saved", img.size)
