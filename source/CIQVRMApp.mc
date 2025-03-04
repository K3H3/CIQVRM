import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;
using Toybox.System;
using Toybox.Communications;
using Toybox.Timer;
using Toybox.Application.Storage;
using Toybox.Graphics;

class CIQVRMApp extends Application.AppBase {
  /*
  To do:
    - use Strings in Menulist
    - handle bad user input (check api responses)
    - password anonymization
    - error handling
  */

  // Private member variables for sensitive data
  private var token = null;
  private var idSite as Number = -1; // Initialize as -1 to check later
  private var username = null;
  private var password = null;

  // URLs for API interactions
  private var batteryDeviceBaseUrl as String;
  private var solarChargerBaseUrl as String;
  private var installationBaseUrl as String;

  // Device-related data
  private var batteryDeviceInstance = null;

  // Timer and flag for periodic requests
  private var requestTimer = new Timer.Timer();
  private var periodicalTimer = new Timer.Timer();

  // Variables to store persistent data
  private var totalScW as Number = 0;
  private var totalSoC as Number = 0;

  function initialize() {
    AppBase.initialize();
    loadUserData();
  }

  function loadUserData() {
    var storedId = Storage.getValue("idSite");
    var storedUsername = Storage.getValue("username");
    var storedPassword = Storage.getValue("password");

    if (storedId != null) {
      idSite = storedId.toNumber();
      System.println("ID Site: " + idSite);
      constructBaseUrls();
    } else {
      System.println("Error: Installation ID not set");
      var pickerView = new WatchUi.View();
    }

    if (storedUsername != null) {
      username = storedUsername.toString();
      System.println("Username: " + username);
    } else {
      System.print("Username not set");
      var pickerView = new WatchUi.View();
    }

    if (storedPassword != null) {
      password = storedPassword.toString();
      System.println("Password: " + password);
    } else {
      System.print("Password not set");
      var pickerView = new WatchUi.View();
    }

    if (idSite != -1 && username != null && password != null) {
      askForToken();
      periodicalTimer.start(method(:onPeriodicRoutine), 5000, true);
    }
  }

  private function showCredentialsPicker() {
    System.println("Error: Credentials not set");
    var pickerView = new WatchUi.View();
  }

  private function onIdSiteSelected(value as String) as Void {
    idSite = value.toNumber();
    Storage.setValue("idSite", idSite);
    constructBaseUrls();
    askForToken();
  }

  function askForScW() {
    var davidRequestUrl =
      "https://vrmapi.victronenergy.com/v2/installations/"+ idSite + "/stats?show_instance=true&attributeCodes[0]=ScW&type=custom&interval=15mins&start=" +
      (Time.now().value() - 60).toString();
    var options = {
      :method => Communications.HTTP_REQUEST_METHOD_GET,
      :headers => {
        "X-Authorization" => "Bearer " + token,
      },
      :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON,
    };

    Communications.makeWebRequest(
      davidRequestUrl,
      null,
      options,
      method(:onScWResponse)
    );
  }

  function onScWResponse(
    responseCode as Number,
    data as Null or Dictionary or String
  ) as Void {
    if (responseCode == 200) {
      analyzeScWResponse(data);
    } else {
      System.println("David Response: " + responseCode);
    }
  }

  function analyzeScWResponse(inputData) {
    var ScWSum = 0;
    if (inputData["success"] == true) {
      var records = inputData["records"];
      for (var i = 0; i < records.size(); i++) {
        var stats = records[i]["stats"];
        // System.println(records[i]["stats"]);
        if (stats["ScW"] != false) {
          var scwValues = stats["ScW"];
          for (var j = 0; j < scwValues.size(); j++) {
            ScWSum += scwValues[j][1].toNumber();
          }
        }
      }
      totalScW = ScWSum;
      Storage.setValue("totalScW", totalScW);
      displayValues();
    }
  }

  function displayValues() {
    var storedSoC = Storage.getValue("totalSoC");
    if (storedSoC != null) {
      totalSoC = storedSoC.toNumber();
    } else {
      totalSoC = 0;
    }
    System.println("Total SOC: " + totalSoC);
    System.println("Total ScW: " + totalScW);
    WatchUi.requestUpdate();
  }

  private function constructBaseUrls() {
    if (idSite != -1) {
      installationBaseUrl =
        "https://vrmapi.victronenergy.com/v2/installations/" + idSite;
      batteryDeviceBaseUrl =
        installationBaseUrl + "/widgets/BatterySummary?instance=";
      solarChargerBaseUrl =
        installationBaseUrl + "/widgets/SolarChargerSummary?instance=";
    } else {
      System.println("Error: Base URL cannot be constructed without ID Site");
    }
  }

  function askForToken() {
    var login_url = "https://vrmapi.victronenergy.com/v2/auth/login"; // set the url

    var params = {
      "username" => username,
      "password" => password,
    };

    var options = {
      :method => Communications.HTTP_REQUEST_METHOD_POST,
      :headers => {
        "Content-Type" => Communications.REQUEST_CONTENT_TYPE_JSON,
      },
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
      },
      :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON,
    };

    Communications.makeWebRequest(
      installationBaseUrl + "/system-overview",
      null,
      options,
      method(:onInstalledDevices)
    );
  }

  function onPeriodicRoutine() {
    System.println("PR: Total ScW: " + totalScW);
    System.println("PR: Total SoC: " + totalSoC);
    WatchUi.requestUpdate();
    totalScW = 0;
    totalSoC = 0;
    askForScW();
    askForBatteryInfo(batteryDeviceBaseUrl + batteryDeviceInstance);
  }

  function askForBatteryInfo(batteryUrl) {
    var options = {
      :method => Communications.HTTP_REQUEST_METHOD_GET,
      :headers => {
        "X-Authorization" => "Bearer " + token,
      },
      :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON,
    };

    Communications.makeWebRequest(
      batteryUrl,
      null,
      options,
      method(:onBatteryInfo)
    );
  }

  function onStart(state as Dictionary?) as Void {
    var storedIdSite = Storage.getValue("idSite");
    if (storedIdSite == null || storedIdSite == -1) {
    } else {
      idSite = storedIdSite.toNumber();
    }
  }

  function onStop(state as Dictionary?) as Void {}

  // Return the initial view of your application here
  function getInitialView() as [Views] or [Views, InputDelegates] {
    return [new CIQVRMView(), new CIQVRMDelegate()];
  }

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
        token = (data as Dictionary)["token"];
        Storage.setValue("token", token);
      } else {
        System.println("Error: Invalid data received");
        return;
      }
      askForScW();
      askForInstalledDevices();
    } else if (responseCode == 200) {
      askForScW();
      askForInstalledDevices();
    } else if (responseCode == 401) {
      askForToken();
      System.println("Response: " + responseCode);
    } else {
      System.println("ELSE: " + responseCode);
    }
  }

  function onInstalledDevices(
    responseCode as Number,
    installedDevices as Null or Dictionary or String
  ) {
    if (responseCode == 200) {
      filterForTotalBattery(installedDevices);
    } else {
      System.println("Response: " + responseCode);
    }
  }

  function filterForTotalBattery(installedDevices) {
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
            if (
              deviceDict["customName"]
                .toString()
                .toLower()
                .equals("total battery")
            ) {
              batteryDeviceInstance = deviceDict["instance"];
              askForBatteryInfo(
                batteryDeviceBaseUrl + deviceDict["instance"].toNumber()
              );
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

  function onBatteryInfo(
    responseCode as Number,
    data as Null or Dictionary or String
  ) as Void {
    if (responseCode == 200) {
      var socValue = parseResponseForCode(
        data,
        "SOC",
        "valueFormattedWithUnit",
        false
      );
      if (socValue != null) {
        totalSoC = socValue.toNumber();
      }
      Storage.setValue("totalSoC", totalSoC);
      WatchUi.requestUpdate();
    } else {
      System.println("Response: " + responseCode);
    }
  }

  function parseResponseForCode(response, code, valueKey, isSum as Boolean) {
    var result = null;
    if (response["records"] != null && response != null) {
      var records = response["records"];
      if (records != null && records["data"] != null) {
        var dataNumbersDict = records["data"];
        var dataLength = dataNumbersDict.size();
        var keys = dataNumbersDict.keys();
        for (var i = 0; i < dataLength; i++) {
          var key = keys[i];
          var value = null;
          if (dataNumbersDict[key] instanceof Dictionary) {
            value = dataNumbersDict[key]["code"];
            if (value != null && value.toString().equals(code)) {
              result = dataNumbersDict[key][valueKey];
              // System.println("Result for " + code + ": " + result);
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

  function resetUserData() {
    // Clear storage values
    Storage.clearValues();

    // Reset member variables
    token = null;
    idSite = -1;
    totalScW = 0;
    totalSoC = 0;
    batteryDeviceInstance = null;

    // Stop timers
    periodicalTimer.stop();
    requestTimer.stop();

    // Ensure no further requests are made
    periodicalTimer = new Timer.Timer();
    requestTimer = new Timer.Timer();

    // Update UI
    WatchUi.requestUpdate();

    System.println("User data has been reset");
  }

}

class StringPickerDelegate extends WatchUi.PickerDelegate {
  function initialize() {
    WatchUi.PickerDelegate.initialize();
  }

  function onSelect(value as String) {
    getApp().onIdSiteSelected(value);
  }

  function onCancel() {
    System.println("Picker canceled");
  }
}

function getApp() as CIQVRMApp {
  return Application.getApp() as CIQVRMApp;
}
