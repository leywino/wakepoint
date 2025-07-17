// ─────────────────────────────────────────────
// ▶ App Info
// ─────────────────────────────────────────────
const String appName = "WakePoint";

// ─────────────────────────────────────────────
// ▶ Location Labels
// ─────────────────────────────────────────────
const String labelUnknownLocation = "Unknown Location";
const String labelCurrentLocation = "Current Location";
const String labelAddLocation = "Add Location";

// ─────────────────────────────────────────────
// ▶ Input Labels & Hints
// ─────────────────────────────────────────────
const String labelSearch = "Search";
const String labelManualEntry = "Manual Entry";
const String labelFetching = "Fetching...";
const String hintUseCurrentLocation = "Use Current Location";
const String hintPasteCoordinates = "Paste or enter coordinates (lat,lng)";
const String hintEnterPlace = "Enter a city or place";

// ─────────────────────────────────────────────
// ▶ Alarm UI Text
// ─────────────────────────────────────────────
const String labelSetAlarm = "Set Alarm";
const String titleWakePointAlert = "WakePoint Alert!";
const String msgYouAreNear = "You are near ";
const String btnDismissAlarm = "Dismiss Alarm";
const String msgAlreadyWithinRadius =
    "You're already within the destination radius.";
const String msgFetchingLocation = "Fetching your location...";
const String msgUnableToFetch = "Fetching your location...";

// ─────────────────────────────────────────────
// ▶ Tracking Status Messages
// ─────────────────────────────────────────────
const String labelNotTracking = "Not Tracking";
const String labelDistance = "Distance:";
const String msgNoAlarms =
    "There are no alarms, please add a location using the button below.";
const String msgStopTrackingFirst = "Please stop tracking before selecting";

// ─────────────────────────────────────────────
// ▶ Permissions
// ─────────────────────────────────────────────
const String permLocation = "Location Permission";
const String permNotification = "Notification Permission";
const String permBattery = "Battery Optimization";
const String permOverlay = "Overlay Permission";
String msgPermissionExplanation(String name) =>
    "To enable $name, please open settings and grant the required permission.";

// ─────────────────────────────────────────────
// ▶ Setup Onboarding
// ─────────────────────────────────────────────
const String titleWelcome = "Welcome!";
const String msgPickDefaults =
    "Let's pick some defaults. You can always change these in settings later.";
const String labelRequired = "Required";
const String msgLocationRequired =
    "To track your location, please grant the Location Permission.";
const String msgNotificationRequired =
    "For alerts and notifications, please grant the Notification Permission.";
const String labelOptional = "Optional but Recommended";
const String msgBatteryRecommended =
    "Background Battery Usage to prevent app interruptions.";
const String msgPreventInterruption =
    "Prevent app interruptions by allowing Background Battery Usage.";
const String msgOverlayRecommended =
    "Show alerts over lock screen by allowing Overlay Permission.";
const String btnGetStarted = "Get Started";

// ─────────────────────────────────────────────
// ▶ Permissions UI
// ─────────────────────────────────────────────
const String labelGranted = "Granted";
const String btnGrant = "Grant";

// ─────────────────────────────────────────────
// ▶ Settings Sections
// ─────────────────────────────────────────────
const String sectionSettings = "Settings";
const String sectionGeneral = "General";
const String sectionTracking = "Tracking";
const String sectionAlarm = "Alarm Settings";
const String sectionNotifications = "Notifications";
const String sectionPermissions = "Permissions";

// ─────────────────────────────────────────────
// ▶ Theme
// ─────────────────────────────────────────────
const String labelTheme = "Theme";
const String valSystemDefault = "System Default";
const String valLightMode = "Light Mode";
const String valDarkMode = "Dark Mode";

// ─────────────────────────────────────────────
// ▶ Units
// ─────────────────────────────────────────────
const String labelUnitSystem = "Units";
const String labelMetric = "Metric (meters, kilometers)";
const String labelImperial = "Imperial (yards, miles)";

// ─────────────────────────────────────────────
// ▶ Tracking Configuration
// ─────────────────────────────────────────────
const String labelTrackingRadius = "Alarm Trigger Radius";
const String labelSelectRadius = "Select Alarm Radius";
const String labelMeters = "meters";
const String labelVibration = "Vibration";
const String labelUseOverlayAlarm = "Use Overlay Alarm";
const String msgOverlayRequired =
    "Overlay permission is required for this feature";
const String btnApply = "Apply";

// ─────────────────────────────────────────────
// ▶ Accuracy
// ─────────────────────────────────────────────
const String labelTrackingAccuracy = "Tracking Accuracy";
const String valHighAccuracy = "High Accuracy";
const String valBalanced = "Balanced";
const String valBatterySaving = "Battery Saving";
String msgInvalidAccuracy(String value) => "Invalid accuracy value: $value";

// ─────────────────────────────────────────────
// ▶ Notification Settings
// ─────────────────────────────────────────────
const String labelNotifyWhenNearby = "Notify Only When Nearby";
const String labelNotificationRadius = "Notification Range";
const String descNotifyWhenNearby =
    "Enable to receive alerts only when you're close to your destination.";
const String descNotificationRadius =
    "Set how close you need to be for alerts to trigger.";
const String labelPersistentNotification = "Persistent Notification";
const String descEnablePersistent =
    "Enable Persistent Notification to keep the app running in the background.";
const String msgOverlayNeededForAlerts =
    "Required to show alerts over the lock screen.";
const String msgBatteryNeededForPersistence =
    "Required to prevent the app from being stopped by the system.";

// ─────────────────────────────────────────────
// ▶ Location Provider Notifications
// ─────────────────────────────────────────────
// const String kNotificationTrackingTitle = "Tracking Active";
const String kNotificationTrackingText = "Tracking location in background...";
const String kNotificationAlarmChannelId = "wakepoint_alarm";
const String kNotificationTrackingChannelId = "wakepoint_tracking";


// ─────────────────────────────────────────────
// ▶ Location Provider Toasts/Messages
// ─────────────────────────────────────────────
const String kLogInitialPositionFailed = "Failed to get initial position:";
const String kLogOverlayAlarmFailed = "Overlay alarm failed:";
const String kLogDistanceAboveThreshold =
    "Distance (%s m) is above notification threshold (%r m). Not sending update.";
const String kReachedLocationPrefix = "Reached "; // Used for alarm notification text

// ─────────────────────────────────────────────
// ▶ Method Channel
// ─────────────────────────────────────────────
const String kMethodChannelAlarm = "com.leywin.wakepoint/alarm";

// ─────────────────────────────────────────────
// ▶ General UI
// ─────────────────────────────────────────────
const String btnCancel = "Cancel";
const String btnOpenSettings = "Open Settings";

// ─────────────────────────────────────────────
// ▶ APIs
// ─────────────────────────────────────────────
const String baseUrlOla = "https://api.olamaps.io";
const String endpointAutocomplete = "$baseUrlOla/places/v1/autocomplete";
