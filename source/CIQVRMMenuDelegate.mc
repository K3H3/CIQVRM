import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;



class CIQVRMMenuDelegate extends WatchUi.MenuInputDelegate {

    var ciqapp = new CIQVRMApp();

    function initialize() {
        MenuInputDelegate.initialize();
    }

    function onMenuItem(item as Symbol) as Void {
        if (item == :get_data) {
            System.println("Ask for Battery Data.");
            ciqapp.askForToken();
        } else if (item == :delete_user_data) {
            System.println("Delete User Data");
            ciqapp.resetUserData();
        }
    }

}