import Toybox.Application;
import Toybox.Background;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.WatchUi;

(:background)
class EverdoApp extends Application.AppBase {

    private var _view as EverdoView?;
    private var _pending as PropertyValueType;

    public function initialize() {
        AppBase.initialize();
    }

    public function onStart(state as Dictionary?) as Void {
        Config.importIfMissing();
    }

    //! A real change event from the phone, so this one is allowed to
    //! overwrite. onStart deliberately is not - see Config.
    public function onSettingsChanged() as Void {
        Config.importFromPhone();
        redraw();
    }

    //! Split out and annotated because the class is (:background): on CIQ
    //! 5.0.0 devices (venu2 family, venusq2, d2airx10) the checker rejected
    //! a WatchUi call inside onSettingsChanged outright, since WatchUi is
    //! not linked into the background build. Newer devices happened to let
    //! it pass, which is exactly the kind of difference that only shows up
    //! when you build for every target.
    (:typecheck(disableBackgroundCheck))
    private function redraw() as Void {
        WatchUi.requestUpdate();
    }

    //! Re-arm on the way out: the point is for delivery to continue once the
    //! app is closed.
    public function onStop(state as Dictionary?) as Void {
        registerFlush();
    }

    //! The class is (:background), so the UI types it names here do not exist
    //! in the background build. This method is never reached from there -
    //! tell the checker so rather than dropping the annotation, which is what
    //! keeps WatchUi out of the 64 KB background budget in the first place.
    (:typecheck(disableBackgroundCheck))
    public function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        var v = new $.EverdoView(_pending);
        _view = v;
        return [v, new $.EverdoDelegate(v)];
    }

    public function getServiceDelegate() as [System.ServiceDelegate] {
        return [new $.FlushService()];
    }

    (:typecheck(disableBackgroundCheck))
    public function onBackgroundData(data as PropertyValueType) as Void {
        _pending = data;
        var v = _view;
        if (v != null) {
            v.setBackgroundResult(data);
            WatchUi.requestUpdate();
        }
    }

    //! Thirty minutes. The unit matters: Time.Duration takes SECONDS, so
    //! new Time.Duration(30) would be half a minute and throw.
    //!
    //! This is purely a battery decision, not a throughput one. Measured on
    //! hardware at ~151-174 ms per request, so a single background window
    //! drains roughly 100 items - any realistic capture queue goes out in
    //! one pass, and a longer interval costs nothing but latency. Meanwhile
    //! the target machine is usually asleep, so a frequent poll would burn
    //! radio for nothing. The platform floor is 5 min; there is no reason to
    //! go near it.
    //!
    //! Latency is covered from the other end anyway: capture triggers an
    //! immediate flush, and so does opening the app.
    const FLUSH_INTERVAL_SEC = 1800;

    public function registerFlush() as Void {
        try {
            Background.registerForTemporalEvent(new Time.Duration(FLUSH_INTERVAL_SEC));
        } catch (e) {
            // InvalidBackgroundTimeException - an event fired too recently.
            // Nothing to do; the existing registration stands.
        }
    }
}
