//
// Store-and-forward queue. Shared between the foreground app and the
// background service, so it must stay clean of any WatchUi reference -
// the (:background) build strips UI code and will not link against it.
//
// Entries are plain Dictionaries of primitives because that is all
// Application.Storage can persist. The Venu X1 gives us 10 MB of app
// storage, so depth is not a practical concern; the cap below exists only
// to stop an unnoticed failure growing without bound.
//
import Toybox.Application.Storage;
import Toybox.Lang;
import Toybox.Time;

(:background)
module Outbox {

    const KEY = "outbox";
    const MAX_DEPTH = 500;

    //! Read the queue. Always returns an array, even on first run.
    function load() as Array {
        var v = Storage.getValue(KEY);
        if (v instanceof Lang.Array) {
            return v as Array;
        }
        return [] as Array;
    }

    function save(items as Array) as Void {
        Storage.setValue(KEY, items as Array<Storage.ValueType>);
    }

    function depth() as Number {
        return load().size();
    }

    //! Append a capture. Returns the new depth, or -1 if the queue is full.
    function add(title as String) as Number {
        var items = load();
        if (items.size() >= MAX_DEPTH) {
            return -1;
        }
        items.add({ "t" => title, "ts" => Time.now().value() });
        save(items);
        return items.size();
    }

    //! Drop the head. Called only after a confirmed 2xx - never on an
    //! ambiguous response, because POST /api/items has no idempotency key
    //! and a retry after a lost reply would duplicate the item.
    function removeHead() as Void {
        var items = load();
        if (items.size() > 0) {
            save(items.slice(1, null) as Array);
        }
    }

    //! Title of entry i, or "" if out of range.
    function titleAt(i as Number) as String {
        var items = load();
        if (i < 0 || i >= items.size()) {
            return "";
        }
        var t = (items[i] as Dictionary)["t"];
        return (t instanceof Lang.String) ? t as String : "";
    }

    //! Drop one entry by index, for the queue review screen.
    function removeAt(i as Number) as Void {
        var items = load();
        if (i < 0 || i >= items.size()) {
            return;
        }
        var out = [] as Array;
        for (var j = 0; j < items.size(); j++) {
            if (j != i) {
                out.add(items[j] as Object);
            }
        }
        save(out);
    }

    function clear() as Void {
        save([] as Array);
    }
}
