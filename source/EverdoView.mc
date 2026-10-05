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

    public function initialize(pending as PropertyValueType) {
        View.initialize();
        setBackgroundResult(pending);
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

        if (depth > 0) {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, cy - 70, Graphics.FONT_NUMBER_MEDIUM, depth.toString(),
                Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(cx, cy + 10, Graphics.FONT_XTINY,
                depth == 1 ? "item waiting" : "items waiting",
                Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            dc.setColor(ACCENT, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, cy - 40, Graphics.FONT_MEDIUM, "Ready",
                Graphics.TEXT_JUSTIFY_CENTER);
        }

        if (_status.length() > 0) {
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, cy + 50, Graphics.FONT_XTINY, _status,
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
        f.start(method(:onFlushDone));
    }

    public function onFlushDone(result as Dictionary) as Void {
        _flusher = null;
        var reason = result["reason"];
        var sent = result["sent"];
        var n = (sent instanceof Lang.Number) ? sent as Number : 0;

        if (reason instanceof Lang.String && (reason as String).equals("empty")) {
            // Drained. Only say something if this flush actually did work.
            setStatus(n > 0 ? "sent" : "");
            return;
        }
        if (reason instanceof Lang.String && (reason as String).equals("unconfigured")) {
            setStatus("not configured");
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
