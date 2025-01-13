using Toybox.Time;
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
    var pre_idSite;
    pre_idSite = idSite;
    AppBase.initialize();
    batteryDeviceBaseUrl =
      "https://vrmapi.victronenergy.com/v2/installations/" +
      pre_idSite +
      "/widgets/BatterySummary?instance=";
    solarChargerBaseUrl =
      "https://vrmapi.victronenergy.com/v2/installations/" +
      pre_idSite +
      "/widgets/SolarChargerSummary?instance=";
    //System.println("app-initialize()");
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

  function askForBatteryInfo(batteryUrl) {
    // set token
    Communications.makeWebRequest(
      batteryUrl,
      null,
      {
        :method => 1 as Toybox.Communications.HttpRequestMethod,
        :headers => { "X-Authorization" => "Bearer " + token },
        :responseType => 0 as Toybox.Communications.HttpResponseContentType,
      },
      method(:onBatteryInfo)
    );
  }

  function askForSolarChargerInfo(solarUrl) {
    // set token
    Communications.makeWebRequest(
      solarUrl,
      null,
      {
        :method => 1 as Toybox.Communications.HttpRequestMethod,
        :headers => { "X-Authorization" => "Bearer " + token },
        :responseType => 0 as Toybox.Communications.HttpResponseContentType,
      },
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
      System.println("Response: 401"); // print response code
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
      var devices = installedDevices["records"]["devices"];

      if (devices != null) {
        var devicesSize = devices.size();

        // iterate through each device
        for (var i = 0; i < devicesSize; i += 1) {
          var deviceDict = devices[i];
          if (deviceDict["name"].toString().equals("Battery Monitor")) {
            installedDevices /*>currentBattyCon<*/ =
              deviceDict["lastConnection"].toNumber();
            // get the instance of the battery monitor that had the last connection
            if (batteryLastCon == null) {
              batteryLastCon = installedDevices /*>currentBattyCon<*/;
              currentBatteryInstance = deviceDict["instance"];
            } else if (
              batteryLastCon < installedDevices /*>currentBattyCon<*/
            ) {
              batteryLastCon = installedDevices /*>currentBattyCon<*/;
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
    var pre_batteryDeviceInstance;
    pre_batteryDeviceInstance = batteryDeviceInstance;
    if (pre_batteryDeviceInstance != null) {
      askForBatteryInfo(batteryDeviceBaseUrl + pre_batteryDeviceInstance);
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
      for (var i = 0; i < keys.size(); i += 1) {
        solarChargerDeviceInstance = solarChargerDict[keys[i]];
        index /*>solarChargerUrl<*/ =
          solarChargerBaseUrl + solarChargerDeviceInstance.toString();
        askForSolarChargerInfo(index /*>solarChargerUrl<*/);
        System.println(index /*>solarChargerUrl<*/);
      }
    }
  }

  function onBatteryInfo(
    responseCode as Number,
    data as Null or Dictionary or String
  ) as Void {
    if (responseCode == 200) {
      parseResponseForCode(data, "SOC", "valueFormattedWithUnit", false);
    } else {
      System.println("Response: " + responseCode); // print response code
    }
  }

  function onSolarChargerInfo(
    responseCode as Number,
    data as Null or Dictionary or String
  ) as Void {
    if (responseCode == 200) {
      // get combined Watts for all solar chargers
      parseResponseForCode(data, "ScW", "formattedValue", true);
    } else if (responseCode == -101) {
      System.println("oSC KEINE AHNUNG DIGGER");
    } else {
      System.println("oSC Response: " + responseCode); // print response code
    }
  }

  function filterSolarChargers(installedDevices) {
    // check if top level in installedDevices JSON is "records" key, and create an array of the underlying data
    var now = new Time.Moment(Time.now().value());
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
            var name = deviceDict["name"];

            if (name.toString().equals("Solar Charger")) {
              //create 2 sized array of solar chargers with index number and instance number
              solarChargerAmount += 1;
              solarChargerDict[solarChargerAmount] = deviceDict["instance"];

              // System.println(
              //   "Solar Charger Dict: " +
              //     solarChargerDict +
              //     " + solarChargerAmount: " +
              //     solarChargerAmount +
              //     " + solarChargerInstance " +
              //     solarChargerInstance
              // );

              // check for timeouts
              if (
                now
                  .subtract(
                    new Time.Moment(deviceDict["lastConnection"].toNumber())
                  )
                  .value() > 1800
              ) {
                System.println("Solar Charger: " + name + " is offline");
              }
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
    var sumOfWatts = 0;

    if (response["records"] != null && response != null) {
      response /*>records<*/ = response["records"];
      // check if records has "data" dict.
      if (
        response /*>records<*/ != null &&
        response /*>records<*/["data"] != null
      ) {
        // Get the data
        var dataNumbersDict = response /*>records<*/["data"];
        var dataLength = dataNumbersDict.size();
        var keys = dataNumbersDict.keys();

        // iterate through each entry in "data" dict.
        {
          response /*>i<*/ = 0;
          for (; response /*>i<*/ < dataLength; response /*>i<*/ += 1) {
            var key = keys[response /*>i<*/];
            var value;

            if (dataNumbersDict[key] instanceof Dictionary) {
              value = dataNumbersDict[key]["code"];

              if (value != null && value.toString().equals(code)) {
                result = dataNumbersDict[key][valueKey];
                // check if sum is needed and build sum
                if (isSum) {
                  sumOfWatts = sumOfWatts + result.toNumber();
                } else {
                  System.println("Result for " + code + ": " + result);
                }
              }
            }
          }
        }
      }
      if (isSum) {
        System.println("Sum of Watts: " + sumOfWatts);
        return sumOfWatts;
      } else {
        return result;
      }
    } else {
      System.println("Records not found");
    }
  }
}

function getApp() as CIQVRMApp {
  return Application.getApp() as CIQVRMApp;
}
