import Toybox.Lang;
import Toybox.WatchUi;

class EverdoDelegate extends WatchUi.BehaviorDelegate {

    private var _view as EverdoView;

    public function initialize(view as EverdoView) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    public function onSelect() as Boolean {
        return capture();
    }

    public function onTap(evt as ClickEvent) as Boolean {
        return capture();
    }

    //! Everything that is not "capture" now lives behind the menu. Driving
    //! it all from swipes ran out of gestures as soon as settings needed a
    //! home, and swipe-to-clear-the-queue next to swipe-to-send was asking
    //! for an expensive mis-swipe.
    public function onMenu() as Boolean {
        return openMenu();
    }

    //! Swipe up opens it too. venux1 exposes only two key behaviours,
    //! onSelect and onBack - there is no physical MENU key - so onMenu()
    //! depends on a long-press mapping that may or may not exist on this
    //! firmware. A menu you cannot reach is a menu that does not exist, and
    //! settings live behind it, so bind a gesture that definitely fires.
    public function onNextPage() as Boolean {
        return openMenu();
    }

    private function openMenu() as Boolean {
        WatchUi.pushView(new $.MainMenu(), new $.MainMenuDelegate(_view),
            WatchUi.SLIDE_UP);
        return true;
    }

    //! Guarded even though venux1.api.debug.xml lists TextPicker: support is
    //! per-firmware, not just per-device, and Garmin have said the simulator
    //! does not model that difference.
    private function capture() as Boolean {
        if (WatchUi has :TextPicker) {
            WatchUi.pushView(new WatchUi.TextPicker(""), new $.CaptureListener(_view), WatchUi.SLIDE_UP);
        } else {
            _view.setStatus("no TextPicker on this firmware");
        }
        return true;
    }
}

class CaptureListener extends WatchUi.TextPickerDelegate {

    private var _view as EverdoView;

    public function initialize(view as EverdoView) {
        TextPickerDelegate.initialize();
        _view = view;
    }

    public function onTextEntered(text as String, changed as Boolean) as Boolean {
        _view.enqueue(text);
        return true;
    }

    public function onCancel() as Boolean {
        return true;
    }
}
