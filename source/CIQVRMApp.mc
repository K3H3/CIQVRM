import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;
using Toybox.System;
using Toybox.Communications;

class CIQVRMApp extends Application.AppBase {
  /* to do:
 - input for credentials
 - input for installation id
 - display data
  */

  var token = null;
  var idSite as Number = IDSITE;

  var batteryDeviceInstance = null;
  var batteryDeviceBaseUrl as String;

  var solarChargerAmount as Number = 0;
  var solarChargerDeviceInstance = null;
  var solarChargerBaseUrl as String;
  var solarChargerDict = {};

  function initialize() {
    AppBase.initialize();
    batteryDeviceBaseUrl =
      "https://vrmapi.victronenergy.com/v2/installations/" +
      idSite +
      "/widgets/BatterySummary?instance=";
    solarChargerBaseUrl =
      "https://vrmapi.victronenergy.com/v2/installations/" +
      idSite +
      "/widgets/SolarChargerSummary?instance=";
    //System.println("app-initialize()");
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

  function askForBatteryInfo(batteryUrl) {
    var options = {
      :method => Communications.HTTP_REQUEST_METHOD_GET,
      :headers => {
        "X-Authorization" => "Bearer " + token,
      }, // set token
      :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON,
    };

    Communications.makeWebRequest(
      batteryUrl,
      null,
      options,
      method(:onBatteryInfo)
    );
  }

  function askForSolarChargerInfo(solarUrl) {
    var options = {
      :method => Communications.HTTP_REQUEST_METHOD_GET,
      :headers => {
        "X-Authorization" => "Bearer " + token,
      }, // set token
      :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON,
    };

    Communications.makeWebRequest(
      solarUrl,
      null,
      options,
      method(:onSolarChargerInfo)
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
    if (token != null) {
      return;
    }
    // autostart
    if (responseCode == 200) {
      if (data != null && data instanceof Dictionary && data["token"] != null) {
        token = (data as Dictionary)["token"]; // set token to data["token"]
      } else {
        System.println("Error: Invalid data received");
        return;
      }
      askForInstalledDevices();
    } else if (responseCode == 200) {
      askForInstalledDevices();
    } else if (responseCode == 401) {
      askForToken();
      System.println("Response: " + responseCode); // print response code
    } else {
      System.println("ELSE: " + responseCode); // print response code
    }
  }

  function onInstalledDevices(
    responseCode as Number,
    installedDevices as Null or Dictionary or String
  ) {
    if (responseCode == 200) {
      // handle batteries
      filterMostCurrentBattery(installedDevices);
      buildBatteryUrl();

      // handle solar chargers
      filterSolarChargers(installedDevices);
      buildSolarChargerUrl(solarChargerAmount);
    } else {
      System.println("Response: " + responseCode); // print response code
    }
  }

  function filterMostCurrentBattery(installedDevices) {
    // check if top level in installedDevices JSON is "records" key, and create an array of the underlying data
    var batteryLastCon = null;
    var currentBatteryInstance = null;

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
            var currentBattyCon = deviceDict["lastConnection"].toNumber();
            // get the instance of the battery monitor that had the last connection
            if (batteryLastCon == null) {
              batteryLastCon = currentBattyCon;
              currentBatteryInstance = deviceDict["instance"];
            } else if (batteryLastCon < currentBattyCon) {
              batteryLastCon = currentBattyCon;
              currentBatteryInstance = deviceDict["instance"];
            }
            batteryDeviceInstance = currentBatteryInstance;
          }
        }
      } else {
        System.println("Devices not found");
        return;
      }
    } else {
      System.println("Records not found in JSON response");
      return;
    }
  }

  function buildBatteryUrl() {
    if (batteryDeviceInstance != null) {
      var batteryDeviceUrl = "";
      batteryDeviceUrl = batteryDeviceBaseUrl + batteryDeviceInstance;
      askForBatteryInfo(batteryDeviceUrl);
    } else {
      System.println("Battery Device Instance not found");
    }
  }

  function buildSolarChargerUrl(index as Number) {
    // check if solarChargerDict has an index
    if (solarChargerDict.keys().size() == 0) {
      System.println("Error: solarChargerDict is empty");
      return;
    } else {
      var keys = solarChargerDict.keys();
      var solarChargerUrl = "";
      for (var i = 0; i < keys.size(); i++) {
        solarChargerDeviceInstance = solarChargerDict[keys[i]];
        solarChargerUrl =
          solarChargerBaseUrl + solarChargerDeviceInstance.toString();
        var sumOfCharger = askForSolarChargerInfo(solarChargerUrl);
        System.println(solarChargerUrl);
      }
    }
  }

  function onBatteryInfo(
    responseCode as Number,
    data as Null or Dictionary or String
  ) as Void {
    var sumNeeded as Boolean = false;
    if (responseCode == 200) {
      parseResponseForCode(data, "SOC", "valueFormattedWithUnit", sumNeeded);
    } else {
      System.println("Response: " + responseCode); // print response code
    }
  }

  function onSolarChargerInfo(
    responseCode as Number,
    data as Null or Dictionary or String
  ) as Void {
    var sumNeeded as Boolean = true;
    if (responseCode == 200) {
      // get combined Watts for all solar chargers
      parseResponseForCode(data, "ScW", "formattedValue", sumNeeded);
    } else if (responseCode == -101) {
      System.println("oSC KEINE AHNUNG DIGGER");
    } else {
      System.println("oSC Response: " + responseCode); // print response code
    }
  }

  function filterSolarChargers(installedDevices) {
    // check if top level in installedDevices JSON is "records" key, and create an array of the underlying data
    var timeOutTime as Number = 1800;
    var now = new Time.Moment(Time.now().value());
    var solarChargerInstance = null;

    if (installedDevices["records"] != null) {
      var records = installedDevices["records"];
      var devices = records["devices"];

      if (devices != null) {
        var devicesSize = devices.size();

        // iterate through each device
        for (var i = 0; i < devicesSize; i++) {
          var deviceDict = devices[i];
          var name = deviceDict["name"];

          if (name.toString().equals("Solar Charger")) {
            //create 2 sized array of solar chargers with index number and instance number
            solarChargerInstance = deviceDict["instance"];
            solarChargerAmount++;
            solarChargerDict[solarChargerAmount] = solarChargerInstance;

            // System.println(
            //   "Solar Charger Dict: " +
            //     solarChargerDict +
            //     " + solarChargerAmount: " +
            //     solarChargerAmount +
            //     " + solarChargerInstance " +
            //     solarChargerInstance
            // );

            var currentCon = deviceDict["lastConnection"].toNumber();
            var diff = now.subtract(new Time.Moment(currentCon)).value();

            // check for timeouts
            if (diff > timeOutTime) {
              System.println("Solar Charger: " + name + " is offline");
            }
          }
        }
      } else {
        System.println("Devices not found");
        return;
      }
    } else {
      System.println("Records not found in JSON response");
      return;
    }
  }

  function parseResponseForCode(response, code, valueKey, isSum as Boolean) {
    var result = null;

    if (response["records"] != null && response != null) {
      var records = response["records"];
      // check if records has "data" dict.
      if (records != null && records["data"] != null) {
        // Get the data
        var dataNumbersDict = records["data"];
        var dataLength = dataNumbersDict.size();
        var keys = dataNumbersDict.keys();

        // iterate through each entry in "data" dict.
        for (var i = 0; i < dataLength; i++) {
          var key = keys[i];
          var value = null;

          if (dataNumbersDict[key] instanceof Dictionary) {
            value = dataNumbersDict[key]["code"];

            if (value != null && value.toString().equals(code)) {
              result = dataNumbersDict[key][valueKey];

              System.println("Result for " + code + ": " + result);
            }
          }
        }
      }
      return result;
    } else {
      System.println("Records not found");
    }
  }

  function getCurrentToken() as String {
    return token;
  }
}

function getApp() as CIQVRMApp {
  return Application.getApp() as CIQVRMApp;
}
