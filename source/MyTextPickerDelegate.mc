using Toybox.WatchUi;
using Toybox.Application.Storage;

class MyTextPickerDelegate extends WatchUi.TextPickerDelegate {
  var screenMessage = "";

  function initialize() {
    WatchUi.TextPickerDelegate.initialize();
  }

  function onCancel() {
    WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
    screenMessage = "canceled";
  }

  function onTextEntered(text, changed) {
    Storage.setValue("idSite", text.toString());
    getApp().loadIdSite();
  }
}
