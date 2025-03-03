using Toybox.WatchUi;
using Toybox.Application.Storage;

class MyTextPickerDelegate extends WatchUi.TextPickerDelegate {
  var screenMessage = "";
  var inputFieldKey = "";

  function initialize(fieldKey) {
    WatchUi.TextPickerDelegate.initialize();
    inputFieldKey = fieldKey;
  }

  function onCancel() {
    WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
    screenMessage = "canceled";
  }

  function onTextEntered(text, changed) {
    Storage.setValue(inputFieldKey, text.toString());
    getApp().loadUserData();
  }
}
