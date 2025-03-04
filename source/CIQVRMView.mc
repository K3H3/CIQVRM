import Toybox.Graphics;
import Toybox.WatchUi;
using Toybox.Application.Storage;

class CIQVRMView extends WatchUi.View {
  function initialize() {
    View.initialize();
  }

  // Load your resources here
  function onLayout(dc as Dc) as Void {
    setLayout(Rez.Layouts.MainLayout(dc));
  }

  // Called when this View is brought to the foreground. Restore
  // the state of this View and prepare it to be shown. This includes
  // loading resources into memory.
  function onShow() as Void {
    if (Storage.getValue("idSite") == null) {
      createMenu();
    } else if (Storage.getValue("username") == null) {
      createMenu();
    } else if (Storage.getValue("password") == null) {
      createMenu();
    }
  }

  // Update the view
  function onUpdate(dc as Dc) as Void {
    // Call the parent onUpdate function to redraw the layout
    View.onUpdate(dc);
    draw(dc);
  }

  public function draw(dc as Dc) as Void {
    var font = Graphics.FONT_SMALL;
    var displaySolarYield = Storage.getValue("solarYield");
    var displayBatterySoC = Storage.getValue("bs");
    var displayBatteryConsumption = Storage.getValue("consumption");

    // Handle null values
    if (displaySolarYield == null) {
      displaySolarYield = 0;
    }
    if (displayBatterySoC == null) {
      displayBatterySoC = 0;
    }
    if (displayBatteryConsumption == null) {
      displayBatteryConsumption = 0;
    }

    dc.clear();
    var screenHeight = dc.getHeight();
    var screenWidth = dc.getWidth();
    var itemSpacing = screenHeight / 8;

    dc.drawText(
      screenWidth / 2,
      screenHeight / 2 - itemSpacing,
      font,
      "Solar Power: " + displaySolarYield.toString() + " W",
      Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
    );
    dc.drawText(
      screenWidth / 2,
      screenHeight / 2,
      font,
      "Battery: " + displayBatterySoC.toNumber() + " %",
      Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
    );
    dc.drawText(
      screenWidth / 2,
      screenHeight / 2 + itemSpacing,
      font,
      "Consumption: " + displayBatteryConsumption.toString() + " W",
      Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
    );
  }

  function createMenu() {
    var menu = new WatchUi.Menu2({ :title => "Settings" });
    var delegate;

    menu.addItem(
      new MenuItem("Username", Storage.getValue("username"), "onUsername", {})
    );

    menu.addItem(
      new MenuItem("Password", Storage.getValue("password"), "onPassword", {})
    );

    menu.addItem(
      new MenuItem(
        "Installation ID",
        Storage.getValue("idSite"),
        "onIdSite",
        {}
      )
    );

    menu.addItem(new MenuItem("Reset User Data", null, "onReset", {}));

    delegate = new CIQVRMMenuDelegate();

    // Push the Menu2 View set up in the initializer
    WatchUi.pushView(menu, delegate, WatchUi.SLIDE_IMMEDIATE);
  }

  // Called when this View is removed from the screen. Save the
  // state of this View here. This includes freeing resources from
  // memory.
  function onHide() as Void {}
}
