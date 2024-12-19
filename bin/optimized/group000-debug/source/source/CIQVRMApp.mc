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
    // set the url

    var params = {
      // set the parameters
      "username" => "USERNAME",
      "password" => "PASSWORD",
    };

    // set the options
    // set response type
    Communications.makeWebRequest(
      "https://vrmapi.victronenergy.com/v2/auth/login",
      params,
      {
        :method => 3 as Toybox.Communications.HttpRequestMethod,
        :headers => {
          "Content-Type" => 1 as Toybox.Communications.HttpRequestContentType,
        },
        :responseType => 0 as Toybox.Communications.HttpResponseContentType,
      },
      method(:onTokenReceived)
    );
  }

  function askForInstalledDevices() {
    // set token
    Communications.makeWebRequest(
      "https://vrmapi.victronenergy.com/v2/installations/IDSITE/system-overview",
      null,
      {
        :method => 1 as Toybox.Communications.HttpRequestMethod,
        :headers => { "X-Authorization" => "Bearer " + token },
        :responseType => 0 as Toybox.Communications.HttpResponseContentType,
      },
      method(:onInstalledDevices)
    );
  }

  function askBatteryInfo() {
    // var url = "https://vrmapi.victronenergy.com/v2/installations/IDSITE/diagnostics?count=1000"; // set the url
    // set token
    Communications.makeWebRequest(
      "https://vrmapi.victronenergy.com/v2/installations/IDSITE/widgets/BatterySummary?instance=512",
      null,
      {
        :method => 1 as Toybox.Communications.HttpRequestMethod,
        :headers => { "X-Authorization" => "Bearer " + token },
        :responseType => 0 as Toybox.Communications.HttpResponseContentType,
      },
      method(:onBatteryInfo)
    );
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
      var devices = installedDevices["records"]["devices"];

      if (devices != null) {
        var devicesSize = devices.size();

        // iterate through each device
        {
          installedDevices /*>i<*/ = 0;
          for (
            ;
            installedDevices /*>i<*/ < devicesSize;
            installedDevices /*>i<*/ += 1
          ) {
            var deviceDict = devices[installedDevices /*>i<*/];
            if (deviceDict["name"].toString().equals("Battery Monitor")) {
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
      response /*>records<*/ = response["records"];

      // checck if records has "data"
      if (response /*>records<*/["data"] != null) {
        // Get the data
        response /*>data<*/ = response /*>records<*/["data"];

        // check if 51 exists in data
        if (response /*>data<*/["51"] != null) {
          response /*>entry51<*/ = response /*>data<*/["51"];

          if (response /*>entry51<*/["valueFormattedWithUnit"] != null) {
            System.println(
              "Battery SoC: " + response /*>entry51<*/["valueFormattedWithUnit"]
            );
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
}

function getApp() as CIQVRMApp {
  return Application.getApp() as CIQVRMApp;
}
