import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

class EverdoView extends WatchUi.View {

    private const ACCENT = 0x5ABB63;    // the green from the Everdo check

    private var _status as String = "";
    // Held so it survives until the callback fires, and so a second flush
    // cannot start while one is in flight.
    private var _flusher as Flusher?;

    // One-shot, so backing out of Settings does not immediately reopen it.
    // Resets on app start, which is the point - see onShow.
    private var _offeredSetup as Boolean = false;

    public function initialize(pending as PropertyValueType) {
        View.initialize();
        setBackgroundResult(pending);
    }

    //! Go straight to Settings while the app is unconfigured.
    //!
    //! Entering text via the phone ends the app and drops you back to the
    //! watch face, so after setting the first of the two values you would
    //! otherwise have to reopen the app and navigate in again for the
    //! second. Resuming into Settings turns that into: reopen, set the
    //! other one, done.
    //!
    //! Deliberately not a modal wizard - Back still reaches the main view,
    //! because capturing before configuring is legitimate. Notes queue and
    //! go out once the settings exist.
    public function onShow() as Void {
        if (!_offeredSetup && !Config.isConfigured()) {
            _offeredSetup = true;
            var m = new $.SettingsMenu();
            WatchUi.pushView(m, new $.SettingsMenuDelegate(m), WatchUi.SLIDE_LEFT);
        }
    }

    public function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();

        var cx = dc.getWidth() / 2;
        var cy = dc.getHeight() / 2;
        var depth = Outbox.depth();

        if (!Config.isConfigured()) {
            dc.setColor(Graphics.COLOR_ORANGE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, cy - 60, Graphics.FONT_MEDIUM, "Setup needed",
                Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, cy, Graphics.FONT_XTINY, "swipe up, then Settings",
                Graphics.TEXT_JUSTIFY_CENTER);
            drawFooter(dc, cx);
            return;
        }

        // Headline sits above centre, caption under it, status below that -
        // spaced off the font heights rather than hand-tuned offsets, which
        // is what kept crowding the lines together.
        if (depth > 0) {
            var fh = dc.getFontHeight(Graphics.FONT_NUMBER_MEDIUM);
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, cy - fh, Graphics.FONT_NUMBER_MEDIUM, depth.toString(),
                Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, cy - 6, Graphics.FONT_XTINY,
                depth == 1 ? "item waiting" : "items waiting",
                Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            dc.setColor(ACCENT, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, cy - dc.getFontHeight(Graphics.FONT_MEDIUM),
                Graphics.FONT_MEDIUM, "Ready", Graphics.TEXT_JUSTIFY_CENTER);
        }

        if (_status.length() > 0) {
            dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, cy + 34, Graphics.FONT_XTINY, _status,
                Graphics.TEXT_JUSTIFY_CENTER);
        }
        drawFooter(dc, cx);
    }

    private function drawFooter(dc as Dc, cx as Number) as Void {
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, dc.getHeight() - 56, Graphics.FONT_XTINY,
            "tap to capture", Graphics.TEXT_JUSTIFY_CENTER);
    }

    public function setStatus(s as String) as Void {
        _status = s;
        WatchUi.requestUpdate();
    }

    //! Result of a flush that ran while the app was closed.
    public function setBackgroundResult(data as PropertyValueType) as Void {
        if (!(data instanceof Lang.Dictionary)) {
            return;
        }
        var sent = (data as Dictionary)["sent"];
        if (sent instanceof Lang.Number && (sent as Number) > 0) {
            _status = "sent " + sent.toString() + " in background";
        }
    }

    public function enqueue(text as String) as Void {
        if (text.length() == 0) {
            return;
        }
        var d = Outbox.add(text);
        if (d < 0) {
            setStatus("queue full");
            return;
        }
        setStatus("saved");
        flushNow();
    }

    //! Single-flight, deliberately. Two Flushers at once would each read the
    //! same head entry and POST it, and since only a confirmed 2xx dequeues,
    //! that lands a duplicate in the inbox - precisely what the retry rule in
    //! Flusher.onResponse exists to avoid. Tapping capture twice quickly is
    //! enough to trigger it.
    public function flushNow() as Void {
        if (_flusher != null) {
            return;
        }
        if (!Config.isConfigured()) {
            setStatus("not configured");
            return;
        }
        setStatus("sending...");
        var f = new Flusher();
        _flusher = f;
        f.start(method(:onFlushDone), 0);          // foreground: no cut-off
    }

    public function onFlushDone(result as Dictionary) as Void {
        _flusher = null;
        var r = result["reason"];
        var reason = (r instanceof Lang.String) ? r as String : "";
        var sent = result["sent"];
        var n = (sent instanceof Lang.Number) ? sent as Number : 0;

        if (reason.equals("empty")) {
            // Drained. Only say something if this flush actually did work.
            setStatus(n > 0 ? (n == 1 ? "sent" : "sent " + n.toString()) : "");
            return;
        }
        if (reason.equals("unconfigured")) {
            setStatus("not configured");
            return;
        }
        if (reason.equals("budget")) {
            // Ran out of time, not an error - whatever is left goes on the
            // next attempt. Reporting the last response code here is what
            // produced the nonsense "sent 1, unexpected (200)".
            setStatus("sent " + n.toString() + ", rest queued");
            return;
        }

        var c = result["code"];
        var code = (c instanceof Lang.Number) ? c as Number : 0;
        var why = Errors.describe(code);
        // Nothing is lost either way - the queue only shrinks on a confirmed
        // 2xx - so lead with what was achieved and follow with the reason.
        setStatus(n > 0 ? "sent " + n.toString() + ", " + why : why);
    }
}
