//
// Where Everdo is and how to authenticate, readable from the background.
//
// Application.Storage is AUTHORITATIVE. It is app-owned and never synced,
// so a value written on the watch stays written. Application.Properties is
// the phone's surface: Garmin Connect Mobile owns it and re-pushes its
// cached copy to the watch, which is why on-watch edits kept reverting.
//
// Properties is therefore an inbox, and it is read at exactly two moments:
//
//   onStart            - only for a key Storage does not have yet, so a
//                        phone-provisioned value works on first run.
//   onSettingsChanged  - a real change event, so a live phone edit lands.
//
// What it deliberately does NOT do is re-read Properties on every start.
// An earlier attempt did, guarded by a mirror of the last imported value,
// and the guard did not hold: set() recorded the value typed on the WATCH,
// so the phone's unchanged stale value then looked like a new phone edit
// and was imported over the top. The key reverted on every launch.
//
// "Use phone settings" in the menu forces an import, for when the phone is
// right and the watch is stale. Explicit beats a heuristic that has already
// been wrong once.
//
import Toybox.Application;
import Toybox.Lang;

(:background)
module Config {

    const BASE_URL = "baseUrl";
    const API_KEY = "apiKey";

    function get(key as String) as String {
        var v = Storage.getValue(key);
        return (v instanceof Lang.String) ? v : "";
    }

    //! Called by the on-watch settings menu. Storage is the copy that
    //! counts; the Properties write is best effort so the phone UI shows
    //! the truth where it can, and is expected to lose to the next sync.
    function set(key as String, value as String) as Void {
        Storage.setValue(key, value);
        Properties.setValue(key, value);
    }

    //! First-run only: fill in what Storage is missing.
    function importIfMissing() as Void {
        importOne(BASE_URL, false);
        importOne(API_KEY, false);
    }

    //! A real phone-side change, or the explicit menu action.
    function importFromPhone() as Void {
        importOne(BASE_URL, true);
        importOne(API_KEY, true);
    }

    function importOne(key as String, force as Boolean) as Void {
        if (!force && get(key).length() > 0) {
            return;
        }
        var p = Properties.getValue(key);
        if (p instanceof Lang.String && (p as String).length() > 0) {
            Storage.setValue(key, p as String);
        }
    }

    function isConfigured() as Boolean {
        return get(BASE_URL).length() > 0 && get(API_KEY).length() > 0;
    }

}
