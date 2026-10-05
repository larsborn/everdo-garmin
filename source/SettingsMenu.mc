//
// On-watch editor for the same Properties the phone app edits.
//
// Each row opens a TextPicker seeded with the current value, so editing is
// a correction rather than a retype - which matters for a 60-character key
// on a 448 px keyboard.
//
import Toybox.Lang;
import Toybox.WatchUi;

class SettingsMenu extends WatchUi.Menu2 {

    public function initialize() {
        Menu2.initialize({ :title => "Settings" });
        addItem(new WatchUi.MenuItem("Base URL", summary(Config.BASE_URL),
            Config.BASE_URL, {}));
        addItem(new WatchUi.MenuItem("API key", summary(Config.API_KEY),
            Config.API_KEY, {}));
    }

    //! Never render the key itself. It is a long-lived credential with full
    //! write access, and a watch face is the one display you cannot control
    //! who is looking at.
    public function summary(key as String) as String {
        var v = Config.get(key);
        if (v.length() == 0) {
            return "not set";
        }
        if (key.equals(Config.API_KEY)) {
            return "set (" + v.length().toString() + " chars)";
        }
        return v;
    }

    public function refresh(key as String) as Void {
        var item = findItemById(key);
        if (item != null) {
            (item as WatchUi.MenuItem).setSubLabel(summary(key));
            WatchUi.requestUpdate();
        }
    }
}

class SettingsMenuDelegate extends WatchUi.Menu2InputDelegate {

    private var _menu as SettingsMenu;

    public function initialize(menu as SettingsMenu) {
        Menu2InputDelegate.initialize();
        _menu = menu;
    }

    public function onSelect(menuItem as WatchUi.MenuItem) as Void {
        var key = menuItem.getId() as String;
        if (!(WatchUi has :TextPicker)) {
            // No keyboard on this device. Say so on the row rather than
            // doing nothing and looking broken - the phone can still edit
            // these, since both editors write the same values.
            menuItem.setSubLabel("edit in the phone app");
            WatchUi.requestUpdate();
            return;
        }
        WatchUi.pushView(new WatchUi.TextPicker(Config.get(key)),
            new $.SettingTextDelegate(_menu, key), WatchUi.SLIDE_UP);
    }
}

class SettingTextDelegate extends WatchUi.TextPickerDelegate {

    private var _menu as SettingsMenu;
    private var _key as String;

    public function initialize(menu as SettingsMenu, key as String) {
        TextPickerDelegate.initialize();
        _menu = menu;
        _key = key;
    }

    public function onTextEntered(text as String, changed as Boolean) as Boolean {
        Config.set(_key, text);
        _menu.refresh(_key);
        return true;
    }

    public function onCancel() as Boolean {
        return true;
    }
}
