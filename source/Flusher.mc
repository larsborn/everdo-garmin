//
// Drains the outbox one request at a time, measuring as it goes.
//
// Requests are CHAINED, never fired in parallel: GarminHomeAssistant hit
// Communications.BLE_QUEUE_FULL doing the latter and found ~600 ms the
// sustainable floor on a Venu 2. The round trip supplies that spacing by
// itself, and measuring it is the entire point of spike 3.
//
// (:background) because the background service links against this and the
// background build has no UI - keep every WatchUi reference out.
//
import Toybox.Application;
import Toybox.Communications;
import Toybox.Lang;
import Toybox.System;

(:background)
class Flusher {

    // Stop issuing NEW requests past this point. The background service is
    // killed at 30 s with no data at all, so we must exit under our own
    // steam with a result worth reading.
    private const BUDGET_MS = 20000;

    private var _t0 as Number = 0;
    private var _reqAt as Number = 0;
    private var _sent as Number = 0;
    private var _lastCode as Number = 0;
    private var _codes as Array = [];
    private var _rtt as Array = [];
    private var _cb as Method?;

    public function initialize() {
    }

    public function start(cb as Method?) as Void {
        _cb = cb;
        _t0 = System.getTimer();
        _sent = 0;
        _lastCode = 0;
        _codes = [];
        _rtt = [];
        next();
    }

    private function finish(reason as String) as Void {
        var cb = _cb;
        if (cb != null) {
            cb.invoke({
                "reason" => reason,
                "code" => _lastCode,
                "sent" => _sent,
                "left" => Outbox.depth(),
                "ms" => System.getTimer() - _t0,
                "codes" => _codes,
                "rtt" => _rtt
            });
        }
    }

    private function next() as Void {
        var items = Outbox.load();
        if (items.size() == 0) {
            finish("empty");
            return;
        }
        if (System.getTimer() - _t0 > BUDGET_MS) {
            finish("budget");
            return;
        }
        var url = Api.url();
        if (url == null) {
            finish("unconfigured");
            return;
        }
        var item = items[0] as Dictionary;
        _reqAt = System.getTimer();
        Communications.makeWebRequest(
            url,
            { "title" => item["t"] } as Dictionary<Object, Object>,
            {
                :method => Communications.HTTP_REQUEST_METHOD_POST,
                :headers => { "Content-Type" => Communications.REQUEST_CONTENT_TYPE_JSON },
                :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
            },
            method(:onResponse)
        );
    }

    public function onResponse(code as Number, data as Dictionary or String or Null) as Void {
        _codes.add(code);
        _rtt.add(System.getTimer() - _reqAt);
        _lastCode = code;

        if (code == 200 || code == 201) {
            // Only a confirmed 2xx drops the head. An ambiguous response is
            // left queued on purpose: /api/items takes no idempotency key,
            // so retrying a write that actually landed duplicates the item.
            Outbox.removeHead();
            _sent++;
            next();
            return;
        }

        // Stop on the first failure and keep the rest queued. The code is
        // carried out in the result so the caller can say something useful
        // rather than "it did not work".
        finish("failed");
    }
}
