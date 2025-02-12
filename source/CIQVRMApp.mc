import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;
using Toybox.System;
using Toybox.Communications;
using Toybox.Timer;
//using Toybox.Application.Storage;

class CIQVRMApp extends Application.AppBase {
  /* to do:
 - sum up solar charger values
 - input for credentials
 - input for installation id
 - display data
  */

  // Private member variables for sensitive data
  private var token = null;
  private var idSite as Number = IDSITE; // Consider externalizing for security.

  // URLs for API interactions
  private var batteryDeviceBaseUrl as String;
  private var solarChargerBaseUrl as String;
  private var installationBaseUrl as String;

  // Device-related data
  private var batteryDeviceInstance = null;
  private var solarChargerAmount as Number = 0;
  private var solarChargerDeviceInstance = null;
  private var solarChargerDict = {}; // Dictionary to store solar charger data
  private var receivedArr = []; // Array to handle responses

  // Timer and flag for periodic requests
  private var requestTimer = new Timer.Timer();
  private var periodicalTimer = new Timer.Timer();
  private var askOnceFlag as Boolean = false;


  function initialize() {
    AppBase.initialize();
    constructBaseUrls();
  }

  private function constructBaseUrls() {
    installationBaseUrl =
      "https://vrmapi.victronenergy.com/v2/installations/" + idSite;
    batteryDeviceBaseUrl =
      installationBaseUrl + "/widgets/BatterySummary?instance=";
    solarChargerBaseUrl =
      installationBaseUrl + "/widgets/SolarChargerSummary?instance=";
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
    
    var options = {
      :method => Communications.HTTP_REQUEST_METHOD_GET,
      :headers => {
        "X-Authorization" => "Bearer " + token,
      }, // set token
      :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON,
    };

    Communications.makeWebRequest(
      installationBaseUrl + "/system-overview",
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
    askForToken();
  }

  // onStop() is called when your application is exiting
  function onStop(state as Dictionary?) as Void {}

  // Return the initial view of your application here
  function getInitialView() as [Views] or [Views, InputDelegates] {
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
        Storage.setValue("token", token);
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
      var instanceAnswerReceived = parseResponseForCode(
        data,
        "ScS",
        "instance",
        false
      );
      receivedArr.add(instanceAnswerReceived.toString());
      var sumAnswerReceived = parseResponseForCode(
        data,
        "ScW",
        "formattedValue",
        sumNeeded
      );
    } else if (responseCode == -101) {
      //System.println("-101");
      askOnceFlag = true;
      requestTimer.start(method(:receivedTimerCallback), 500, false);
    } else {
      System.println("oSC Response: " + responseCode); // print response code
    }
  }

  function receivedTimerCallback() {
    var dictValues = solarChargerDict.values();
    dictValues.sort(null);

    //var recArr = receivedArr;
    receivedArr.sort(null);

    if (askOnceFlag) {
      for (var i = 0; i < dictValues.size(); i++) {
        for (var j = 0; j < receivedArr.size(); j++) {
          if (dictValues[i].toString().equals(receivedArr[j])) {
            dictValues.remove(dictValues[i]);
          }
        }
      }

      if (dictValues.size() == 0) {
        askOnceFlag = false;
        return;
      }

      for (var i = 0; i < dictValues.size(); i++) {
        var newReqSolarChargerUrl =
          solarChargerBaseUrl + dictValues[i].toString();
        askForSolarChargerInfo(newReqSolarChargerUrl);
      }
    }
  }

  function filterSolarChargers(installedDevices) {
    // check if top level in installedDevices JSON is "records" key, and create an dict of the underlying data
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
            //create 2 sized dict of solar chargers with index number and instance number
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
