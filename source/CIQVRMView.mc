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
    }

    // Update the view
    function onUpdate(dc as Dc) as Void {
        // Call the parent onUpdate function to redraw the layout
        View.onUpdate(dc);
        draw(dc);
    }

    public function draw(dc as Dc) as Void {
        var font = Graphics.FONT_MEDIUM;
        var totalScW = Storage.getValue("totalScW");
        var totalSoC = Storage.getValue("totalSoC");

        dc.clear();
        dc.drawText(dc.getWidth() / 2, dc.getHeight() / 2 - 20, font, "Total ScW: " + totalScW.toString(),
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(dc.getWidth() / 2, dc.getHeight() / 2 + 20, font, "Total SoC: " + totalSoC.toString(),
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Called when this View is removed from the screen. Save the
    // state of this View here. This includes freeing resources from
    // memory.
    function onHide() as Void {
    }

}
