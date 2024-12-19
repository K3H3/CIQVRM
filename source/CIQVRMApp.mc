import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;
using Toybox.System;
using Toybox.Communications;

var token;

class CIQVRMApp extends Application.AppBase {
  function initialize() {
    AppBase.initialize();
    System.println("app-initialize()");
  }

  function askForToken() {
    var login_url = "https://vrmapi.victronenergy.com/v2/auth/login"; // set the url

    var params = {
      // set the parameters
      "username" => "USERNAME",
      "password" => "PASSWORD",
    };

    var options = {
      // set the options
      :method => Communications.HTTP_REQUEST_METHOD_POST,
      :headers => {
        "Content-Type" => Communications.REQUEST_CONTENT_TYPE_JSON,
      },
      // set response type
      :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON,
    };

    Communications.makeWebRequest(
      login_url,
      params,
      options,
      method(:onTokenReceived)
    );
  }

  function askForInstalledDevices() {
    var sys_overview_url =
      "https://vrmapi.victronenergy.com/v2/installations/IDSITE/system-overview";

    var options = {
      :method => Communications.HTTP_REQUEST_METHOD_GET,
      :headers => {
        "X-Authorization" => "Bearer " + token,
      }, // set token
      :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON,
    };

    Communications.makeWebRequest(
      sys_overview_url,
      null,
      options,
      method(:onInstalledDevices)
    );
  }

  function askBatteryInfo() {
    // var url = "https://vrmapi.victronenergy.com/v2/installations/IDSITE/diagnostics?count=1000"; // set the url
    var url =
      "https://vrmapi.victronenergy.com/v2/installations/IDSITE/widgets/BatterySummary?instance=512";
    var options = {
      :method => Communications.HTTP_REQUEST_METHOD_GET,
      :headers => {
        "X-Authorization" => "Bearer " + token,
      }, // set token
      :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON,
    };

    Communications.makeWebRequest(url, null, options, method(:onBatteryInfo));
  }

  // onStart() is called on application start up
  function onStart(state as Dictionary?) as Void {
    // System.println("app-onStart()");
    askForToken();
  }

  // onStop() is called when your application is exiting
  function onStop(state as Dictionary?) as Void {}

  // Return the initial view of your application here
  function getInitialView() as [Views] or [Views, InputDelegates] {
    // System.println("app-getInitialView()");
    return [new CIQVRMView(), new CIQVRMDelegate()];
  }

  // set up the response callback function
  function onTokenReceived(
    responseCode as Number,
    data as Null or Dictionary or String
  ) as Void {
    if (responseCode == 200) {
      token = (data as Dictionary)["token"]; // set token to data["token"]
      // System.println("Token: " + token); // print token
      askForInstalledDevices();
    } else {
      System.println("Response: " + responseCode); // print response code
    }
  }

  function onInstalledDevices(
    responseCode as Number,
    installedDevices as Null or Dictionary or String
  ) {
    if (responseCode == 200) {
      System.println("Installed Devices Received"); // print success

      filterMostCurrentBattery(installedDevices);
    } else {
      System.println("Response: " + responseCode); // print response code
    }
  }

  function filterMostCurrentBattery(installedDevices) {
    // check if top level in installedDevices JSON is "records" key, and create an array of the underlying data
    var batteryLastCon = null;
    var batteryInstance = null;

    if (installedDevices["records"] != null) {
      var records = installedDevices["records"];
      var devices = records["devices"];

      if (devices != null) {
        var devicesSize = devices.size();

        // iterate through each device
        for (var i = 0; i < devicesSize; i++) {
          var deviceDict = devices[i];
          var name = deviceDict["name"];

          if (name.toString().equals("Battery Monitor")) {
            // var currentBattyCon = deviceDict["lastConnection"];
            var currentBattyCon = deviceDict["lastConnection"].toNumber();
            // get the instance of the battery monitor that had the last connection
            if (batteryLastCon == null) {
              batteryLastCon = currentBattyCon;
              batteryInstance = deviceDict["instance"];
            } else if (batteryLastCon < currentBattyCon) {
              batteryLastCon = currentBattyCon;
              batteryInstance = deviceDict["instance"];
            }
          }
        }
        System.println(
          "Most current Battery Instance: " +
            batteryInstance +
            ", Last Connection: " +
            batteryLastCon
        );
      }
    }
  }

  function parseResponse(response) {
    // Check if records exist
    if (response["records"] != null) {
      var records = response["records"];

      // checck if records has "data"
      if (records["data"] != null) {
        // Get the data
        var data = records["data"];

        // check if 51 exists in data
        if (data["51"] != null) {
          var entry51 = data["51"];

          if (entry51["valueFormattedWithUnit"] != null) {
            var batterySoC = entry51["valueFormattedWithUnit"];
            System.println("Battery SoC: " + batterySoC);
          } else {
            System.println("ValueFormattedWithUnit not found");
          }
        } else {
          System.println("51 not found");
        }
      } else {
        System.println("Data not found");
      }
    } else {
      System.println("Records not found");
    }
  }

  function onBatteryInfo(
    responseCode as Number,
    data as Null or Dictionary or String
  ) as Void {
    if (responseCode == 200) {
      parseResponse(data);
    } else {
      System.println("Response: " + responseCode); // print response code
    }
  }

  function getCurrentToken() as String {
    return token;
  }
}

function getApp() as CIQVRMApp {
  return Application.getApp() as CIQVRMApp;
}
