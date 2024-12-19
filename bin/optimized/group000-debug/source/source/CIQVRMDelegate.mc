using Rez;
import Toybox.Lang;
import Toybox.WatchUi;

class CIQVRMDelegate extends WatchUi.BehaviorDelegate {
  function initialize() {
    BehaviorDelegate.initialize();
  }

  function onMenu() as Boolean {
    WatchUi.pushView(
      new Rez.Menus.MainMenu(),
      new CIQVRMMenuDelegate(),
      4 as Toybox.WatchUi.SlideType
    );
    return true;
  }
}
