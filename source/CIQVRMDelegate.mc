import Toybox.Lang;
import Toybox.WatchUi;
using Toybox.Application.Storage;

class CIQVRMDelegate extends WatchUi.BehaviorDelegate {
  function initialize() {
    BehaviorDelegate.initialize();
  }

  function onMenu() as Boolean {
    CIQVRMView.createMenu();
    return true;
  }
}
