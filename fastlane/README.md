fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios beta

```sh
[bundle exec] fastlane ios beta
```

Build and upload to TestFlight

### ios screenshots

```sh
[bundle exec] fastlane ios screenshots
```

Capture App Store screenshots by running the app in the simulator

### ios distribute

```sh
[bundle exec] fastlane ios distribute
```

Distribute a build to an external TestFlight group. Pass group:"Group Name" and optionally build_number:"123"

### ios monitor_and_submit

```sh
[bundle exec] fastlane ios monitor_and_submit
```

Poll TestFlight until a build for the given version is processed, then submit for review. Pass version:"1.0"

### ios submit_with_age_rating

```sh
[bundle exec] fastlane ios submit_with_age_rating
```

Set age rating and submit for App Store review directly via Spaceship

### ios submit

```sh
[bundle exec] fastlane ios submit
```

Submit the latest uploaded build for App Store review

### ios metadata

```sh
[bundle exec] fastlane ios metadata
```

Upload metadata and screenshots to App Store (does not submit for review)

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
