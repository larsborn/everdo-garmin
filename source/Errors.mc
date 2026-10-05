//
// Turns a makeWebRequest response code into something a user can act on.
//
// Everything used to collapse into "offline, will retry", which gave the
// same message to someone out of Bluetooth range and someone whose server
// certificate is not trusted - one of those resolves itself and the other
// never will.
//
// Messages are short because they are rendered on a watch, and phrased as
// what to do rather than what went wrong.
//
// One honest limitation: an untrusted TLS certificate does not get its own
// code. Connect IQ reports it as a plain timeout (-300), the same as an
// unreachable host, so that message has to mention both.
//
import Toybox.Lang;

(:background)
module Errors {

    function describe(code as Number) as String {
        // Negative values are Connect IQ transport errors; positive are HTTP.
        if (code < 0) {
            return transport(code);
        }
        if (code == 401 || code == 403) {
            return "check API key";
        }
        if (code == 404) {
            return "check base URL";
        }
        if (code == 0) {
            return "unknown error";
        }
        if (code >= 500) {
            return "Everdo server error";
        }
        if (code >= 400) {
            return "rejected (" + code.toString() + ")";
        }
        return "unexpected (" + code.toString() + ")";
    }

    function transport(code as Number) as String {
        switch (code) {
            case -1:        // BLE_ERROR
            case -2:        // BLE_HOST_TIMEOUT
            case -3:        // BLE_SERVER_TIMEOUT
            case -4:        // BLE_NO_DATA
            case -104:      // BLE_CONNECTION_UNAVAILABLE
                return "phone not connected";
            case -5:        // BLE_REQUEST_CANCELLED
            case -1003:     // REQUEST_CANCELLED
                return "cancelled";
            case -101:      // BLE_QUEUE_FULL
                return "watch busy, will retry";
            case -102:      // BLE_REQUEST_TOO_LARGE
                return "note too long";
            case -300:      // NETWORK_REQUEST_TIMED_OUT
                return "no reply - URL or certificate?";
            case -400:      // INVALID_HTTP_BODY_IN_NETWORK_RESPONSE
            case -401:      // INVALID_HTTP_HEADER_FIELDS_IN_NETWORK_RESPONSE
            case -1002:     // UNSUPPORTED_CONTENT_TYPE_IN_RESPONSE
                return "unexpected reply - is this Everdo?";
            case -402:      // NETWORK_RESPONSE_TOO_LARGE
            case -403:      // NETWORK_RESPONSE_OUT_OF_MEMORY
                return "reply too large";
            case -1000:     // STORAGE_FULL
                return "watch storage full";
            case -1001:     // SECURE_CONNECTION_REQUIRED
                return "HTTPS required";
            case -1004:     // REQUEST_CONNECTION_DROPPED
                return "connection dropped";
            default:
                return "network error (" + code.toString() + ")";
        }
    }

    //! True when retrying unattended is pointless because a human has to
    //! change something. Used to avoid burning radio on a doomed queue.
    function isFatal(code as Number) as Boolean {
        return code == 401 || code == 403 || code == 404
            || code == -1001 || code == -102;
    }
}
