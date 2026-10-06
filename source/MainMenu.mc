//
// Menu reached by swiping up, or by the MENU behaviour where the device
// has one. venux1 exposes only onSelect and onBack as key behaviours, so
// the swipe is the dependable route and the menu must stay reachable that
// way - settings live behind it.
//
import Toybox.Lang;
import Toybox.WatchUi;

class MainMenu extends WatchUi.Menu2 {

    public function initialize() {
        Menu2.initialize({ :title => "Everdo" });
        addItem(new WatchUi.MenuItem("Send now", null, "flush", {}));
        var n = Outbox.depth();
        if (n > 0) {
            addItem(new WatchUi.MenuItem("Waiting to send", n.toString() + " items",
                "queue", {}));
        }
        addItem(new WatchUi.MenuItem("Settings", null, "settings", {}));
        addItem(new WatchUi.MenuItem("Use phone settings", "overwrite from phone",
            "import", {}));
        addItem(new WatchUi.MenuItem("Discard queue", null, "clear", {}));
    }
}

class MainMenuDelegate extends WatchUi.Menu2InputDelegate {

    private var _view as EverdoView;

    public function initialize(view as EverdoView) {
        Menu2InputDelegate.initialize();
        _view = view;
    }

    public function onSelect(menuItem as WatchUi.MenuItem) as Void {
        var id = menuItem.getId() as String;

        if (id.equals("flush")) {
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
            _view.flushNow();

        } else if (id.equals("queue")) {
            var q = new $.QueueMenu();
            WatchUi.pushView(q, new $.QueueMenuDelegate(q, _view), WatchUi.SLIDE_LEFT);

        } else if (id.equals("settings")) {
            var menu = new $.SettingsMenu();
            WatchUi.pushView(menu, new $.SettingsMenuDelegate(menu), WatchUi.SLIDE_LEFT);

        } else if (id.equals("import")) {
            Config.importFromPhone();
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
            _view.setStatus("imported from phone");

        } else if (id.equals("clear")) {
            // Confirmed, because this throws away captures that have not
            // reached Everdo yet - the one irreversible thing in the app.
            WatchUi.pushView(
                new WatchUi.Confirmation("Discard unsent items?"),
                new $.DiscardConfirmationDelegate(_view),
                WatchUi.SLIDE_UP);
        }
    }
}

class DiscardConfirmationDelegate extends WatchUi.ConfirmationDelegate {

    private var _view as EverdoView;

    public function initialize(view as EverdoView) {
        ConfirmationDelegate.initialize();
        _view = view;
    }

    public function onResponse(response as Confirm) as Boolean {
        if (response == WatchUi.CONFIRM_YES) {
            Outbox.clear();
            _view.setStatus("queue discarded");
        }
        return true;
    }
}
