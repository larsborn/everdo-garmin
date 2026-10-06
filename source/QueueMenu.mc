//
// Review what is waiting to be sent, and drop individual entries.
//
// Before this, a mistyped capture could only be dealt with by discarding
// the entire queue - which also threw away the good items sitting behind
// it. Nothing here edits text: fixing a typo means deleting and
// re-capturing, which is fewer moving parts than an edit flow and about
// the same number of taps.
//
import Toybox.Lang;
import Toybox.WatchUi;

class QueueMenu extends WatchUi.Menu2 {

    private var _count as Number = 0;

    public function initialize() {
        Menu2.initialize({ :title => "Waiting to send" });
        rebuild();
    }

    //! Menu2 has no clear(), so track how many rows we added and remove
    //! exactly those before refilling.
    public function rebuild() as Void {
        for (var i = _count - 1; i >= 0; i--) {
            deleteItem(i);
        }
        var n = Outbox.depth();
        _count = n;
        for (var i = 0; i < n; i++) {
            addItem(new WatchUi.MenuItem(Outbox.titleAt(i), "tap to delete", i, {}));
        }
    }
}

class QueueMenuDelegate extends WatchUi.Menu2InputDelegate {

    private var _menu as QueueMenu;
    private var _view as EverdoView;

    public function initialize(menu as QueueMenu, view as EverdoView) {
        Menu2InputDelegate.initialize();
        _menu = menu;
        _view = view;
    }

    public function onSelect(menuItem as WatchUi.MenuItem) as Void {
        var idx = menuItem.getId();
        if (!(idx instanceof Lang.Number)) {
            return;
        }
        Outbox.removeAt(idx as Number);
        _menu.rebuild();
        _view.setStatus("item deleted");
        if (Outbox.depth() == 0) {
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
        } else {
            WatchUi.requestUpdate();
        }
    }
}
