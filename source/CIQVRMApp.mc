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
  private var idSite as Number = -1; // Initialize as -1 to check later
  private var username = null;
  private var password = null;

  // Timer and flag for periodic requests
  private var periodicalTimer = new Timer.Timer();
  private var requestNewToken = false;
  private var notAgain = false;

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
    } else {
      System.println("Error: Installation ID not set");
      var pickerView = new WatchUi.View();
    }

    if (storedUsername != null) {
      username = storedUsername.toString();
    } else {
      System.print("Username not set");
      var pickerView = new WatchUi.View();
    }

    if (storedPassword != null) {
      password = storedPassword.toString();
    } else {
      System.print("Password not set");
      var pickerView = new WatchUi.View();
    }

    if (idSite != -1 && username != null && password != null) {
      if (Storage.getValue("token").toString().equals("null") == false) {
        fetchStatsData(Storage.getValue("token").toString());
      } else {
        System.println("Token not set, asking for new one");
        askForToken();
      }
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

  function fetchStatsData(token) {
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
    } else if (responseCode == 404) {
      System.println("Error: Installation ID not found");
      // pick new installation ID
    } else if (responseCode == 401) {
      System.println("Error: Unauthorized");
      askForToken();
    } else {
      System.println("Error: " + responseCode);
    }
  }

  function analyzeStatsData(inputData) {
    if (inputData["success"] == true) {
      periodicalTimer.start(method(:onPeriodicRoutine), 10000, true);
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
      handleUnprocessableData();
    }
  }

  function handleUnprocessableData() {
    System.println("Data analyzation failed. Retrying...");
  }

  function askForToken() {
    var login_url = "https://vrmapi.victronenergy.com/v2/auth/login";
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

  function onPeriodicRoutine() {
    WatchUi.requestUpdate();
    fetchStatsData(Storage.getValue("token").toString());
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
    if (responseCode == 200) {
      Storage.setValue("token", (data as Dictionary)["token"].toString());
      fetchStatsData((data as Dictionary)["token"].toString());
    } else if (responseCode == 401) {
      if (Toybox.WatchUi has :showToast) {
        WatchUi.showToast("Bad Token received, check userdata", null);
      }
      requestUserDataCheck();
    } else if (responseCode == 429) {
      System.println("Error: Too many requests");
      return;
      //time out timer start
    } else {
      System.println("ELSE: " + responseCode);
    }
  }

  function requestUserDataCheck() {
    //push settings menu
    var menu = new CIQVRMView();
  }

  function resetUserData() {
    Storage.clearValues();

    // Reset member variables
    idSite = -1;
    currentBatterySoC = 0;
    currentSolarYield = 0;
    currentConsumption = 0;

    // Stop timers
    periodicalTimer.stop();

    // Ensure no further requests are made
    periodicalTimer = new Timer.Timer();

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
