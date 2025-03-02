import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;



class CIQVRMMenuDelegate extends WatchUi.MenuInputDelegate {

    var ciqapp = new CIQVRMApp();

    function initialize() {
        MenuInputDelegate.initialize();
    }

    function onMenuItem(item as Symbol) as Void {
        if (item == :manual_refresh) {
            ciqapp.askForToken();
        } else if (item == :delete_user_data) {
            ciqapp.resetUserData();
        }
    }

}