# FlappyBird 2026

## Google Play Games Services - Godot plugin

For integration with the Google Play Games Services, in particular the use of
the Leaderboard, install the Godot plugin from:

<https://github.com/godot-sdk-integrations/godot-play-game-services>

The leaderboard resource needs to be created on the Google Play Console and the
ID set with "ANDROID_LEADERBOARD_ID" in Main.gd.

## Apple Services - Godot plugin

For integration with Apple Services, install the Godot plugin from:

<https://github.com/migueldeicaza/GodotApplePlugins>

To connect to the leaderboard resource the coresponding ID from the
App Store Connect platform needs to be set with "IOS_LEADERBOARD_ID" in Main.gd.

### Apple plugin workaround

The .gdextension file has macos.arm64 and macos.x86_64 entries, so Godot tries
to load the native Swift framework when the editor starts on macOS.
The NSBundle bundleWithURL: call throws an unhandled exception - likely a code
signing or Swift runtime compatibility issue with macOS version 26.3.1.

Since  iOS is targeted and not macOS desktop, the macOS entries aren't needed.
Removing them will stop Godot from trying to load the framework in the editor,
and the ios entry will still work for iOS exports.

Therefore the following parts are removed from
addons/GodotApplePlugins/godot_apple_plugins.gdextension

```sh
macos.arm64 = "res://addons/GodotApplePlugins/bin/GodotApplePlugins.framework"
macos.x86_64 = "res://addons/GodotApplePlugins/bin/GodotApplePlugins_x64.framework"

macos.arm64 = {
    "res://addons/GodotApplePlugins/bin/SwiftGodotRuntime.framework" : "Contents/Frameworks"
}
macos.x86_64 = {
    "res://addons/GodotApplePlugins/bin/SwiftGodotRuntime_x64.framework" : "Contents/Frameworks"
}
```
