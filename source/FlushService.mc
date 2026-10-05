//
// Background entry point. Runs on the temporal event even when the app is
// closed, which is the whole reason the outbox is worth having: the Everdo
// box is usually asleep, so delivery has to happen opportunistically.
//
import Toybox.Application;
import Toybox.Background;
import Toybox.Lang;
import Toybox.System;

(:background)
class FlushService extends System.ServiceDelegate {

    // Held so it is not collected mid-request, and so a second temporal
    // event cannot start an overlapping drain of the same queue head.
    private var _flusher as Flusher?;

    public function initialize() {
        ServiceDelegate.initialize();
    }

    public function onTemporalEvent() as Void {
        if (_flusher != null) {
            return;
        }
        var f = new Flusher();
        _flusher = f;
        f.start(method(:onFlushDone), 20000);     // killed at 30 s, leave headroom
    }

    //! Background.exit hands this to the app's onBackgroundData, immediately
    //! if it is running or at next launch otherwise. Limit is ~8 KB; a
    //! summary like this is nowhere near it.
    public function onFlushDone(result as Dictionary) as Void {
        Background.exit(result as Application.PropertyValueType);
    }
}
