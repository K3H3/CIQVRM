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
    - remove empty chars from input string (when input with garmin app is used, space chars are added)
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
  private var currentSolarYield as Number = 0;
  private var currentBatterySoC as Number = 0;
  private var currentConsumption as Number = 0;

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
      periodicalTimer.start(method(:onPeriodicRoutine), 10000, true);
    }
  }

  private function showCredentialsPicker() {
    System.println("Error: Credentials not set");
    var pickerView = new WatchUi.View();
  }

  private function onIdSiteSelected(value as String) as Void {
    idSite = value.toNumber();
    Storage.setValue("idSite", idSite);
    askForToken();
  }

  function fetchStatsData() {
    var idSite = Storage.getValue("idSite").toNumber();
    if (idSite == -1) {
      System.println("Error: Installation ID not set: -1");
      return;
    } else if (idSite.toString().equals("null")) {
      System.println("Error: Installation ID not set: null");
      return;
    }

    var fetchStatsUrl =
      "https://vrmapi.victronenergy.com/v2/installations/" +
      idSite +
      "/stats?type=custom&interval=15mins&attributeCodes[0]=bs&attributeCodes[1]=solar_yield&attributeCodes[2]=consumption&start=" +
      (Time.now().value() - 60).toString();
    var options = {
      :method => Communications.HTTP_REQUEST_METHOD_GET,
      :headers => {
        "X-Authorization" => "Bearer " + token,
      },
      :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON,
    };
    Communications.makeWebRequest(
      fetchStatsUrl,
      null,
      options,
      method(:onStatsDataResponse)
    );
  }

  function onStatsDataResponse(
    responseCode as Number,
    data as Null or Dictionary or String
  ) as Void {
    if (responseCode == 200) {
      analyzeStatsData(data);
    } else {
      System.println("Response code: " + responseCode);
    }
  }

  function analyzeStatsData(inputData) {
    System.println(inputData);
    if (inputData["success"] == true) {
      var totals = inputData["totals"];
      var bs = totals["bs"].toString();
      bs = bs.toNumber();
      Storage.setValue("bs", bs);
      var solarYield = totals["solar_yield"].toString();
      solarYield = solarYield.toNumber();
      Storage.setValue("solarYield", solarYield);
      var consumption = totals["consumption"].toString();
      consumption = consumption.toNumber();
      Storage.setValue("consumption", consumption);
    } else {
      System.println("Data analyzation failed.");
    }
  }

  function displayValues() {
    var storedBatterySoC = Storage.getValue("bs");
    if (storedBatterySoC != null) {
      currentBatterySoC = storedBatterySoC.toNumber();
    } else {
      currentBatterySoC = 0;
    }
    System.println("Total Battery SoC: " + currentBatterySoC);
    System.println("Total ScW: " + currentSolarYield);
    WatchUi.requestUpdate();
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
    WatchUi.requestUpdate();
    fetchStatsData();
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
      fetchStatsData();
    } else if (responseCode == 200) {
      fetchStatsData();
    } else if (responseCode == 401) {
      askForToken();
      System.println("Response: " + responseCode);
    } else {
      System.println("ELSE: " + responseCode);
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
    currentBatterySoC = 0;
    currentSolarYield = 0;
    currentConsumption = 0;
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

class Helper extends Application.AppBase {
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
}
