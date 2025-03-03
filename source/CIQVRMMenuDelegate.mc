import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

class CIQVRMMenuDelegate extends WatchUi.Menu2InputDelegate {
  function initialize() {
    Menu2InputDelegate.initialize();
  }

  function onSelect(item) {
    System.println(item.getId());
    if (item.getId().equals("onUsername")) {
      pushPicker("", "username");
    } else if (item.getId().equals("onPassword")) {
      pushPicker("", "password");
    } else if (item.getId().equals("onIdSite")) {
      pushPicker("", "idSite");
    }
  }

  function pushPicker(screenMessage, datafield) as Void {
    WatchUi.pushView(
      new WatchUi.TextPicker(datafield),
      new MyTextPickerDelegate(datafield),
      WatchUi.SLIDE_IMMEDIATE
    );
  }
}
