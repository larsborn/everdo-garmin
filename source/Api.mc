//
// One place that knows how to address Everdo. Both the real flush and the
// latency probe need it, and two copies of the URL assembly is how they
// quietly drift apart.
//
import Toybox.Lang;

(:background)
module Api {

    //! null when unconfigured, so callers fail loudly instead of posting
    //! somewhere unintended.
    function url() as String? {
        if (!Config.isConfigured()) {
            return null;
        }
        return Config.get(Config.BASE_URL) + "/api/items?key=" + Config.get(Config.API_KEY);
    }
}
