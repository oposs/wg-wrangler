/* ************************************************************************
   Copyright: 2021 Tobias Bossert
   License:   ???
   Authors:   Tobias Bossert <bossert _at_ oetiker _this_is_a_dot_ ch>
 *********************************************************************** */

/**
 * Main application class.
 * @asset(wgwrangler/*)
 *
 */
qx.Class.define("wgwrangler.Application", {
    extend : callbackery.Application,
    members : {
        main : function() {
            // Call super class
            this.base(arguments);
        }
    }
});
