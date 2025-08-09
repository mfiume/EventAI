# dSYM Fix for Swift Package Manager Dependencies

## Problem
When archiving the EventAI iOS app, the archive did not include dSYM files for GoogleMobileAds and UserMessagingPlatform frameworks, which are required for:
- Crash reporting and symbolication
- App Store Connect submission 
- TestFlight distribution

## Solution Applied

### 1. Build Settings Added
Added the following build settings to the **Release** configuration:
```
DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
DWARF_DSYM_FOLDER_PATH = "$(BUILT_PRODUCTS_DIR)";
DWARF_DSYM_FILE_NAME = "$(PRODUCT_NAME).app.dSYM";
```

### 2. Run Script Build Phase
Added a "Copy Swift Package dSYMs" build phase with the following script:
```bash
# Copy Swift Package dSYMs for GoogleMobileAds and UserMessagingPlatform
if [ "${CONFIGURATION}" = "Release" ]; then
  echo "Copying Swift Package dSYMs..."
  
  # Find and copy GoogleMobileAds dSYM
  find "${BUILD_DIR}" -name "GoogleMobileAds.framework.dSYM" -exec cp -R {} "${DWARF_DSYM_FOLDER_PATH}/" \;
  
  # Find and copy UserMessagingPlatform dSYM  
  find "${BUILD_DIR}" -name "UserMessagingPlatform.framework.dSYM" -exec cp -R {} "${DWARF_DSYM_FOLDER_PATH}/" \;
  
  echo "Finished copying Swift Package dSYMs"
fi
```

### 3. Build Phase Order
The script runs after Resources but before archiving, ensuring dSYMs are included in the final archive.

## Verification
After archiving, the .xcarchive should now contain:
- `EventAI.app.dSYM/` (main app)
- `GoogleMobileAds.framework.dSYM/` 
- `UserMessagingPlatform.framework.dSYM/`

## References
- [Apple Documentation: Debug Symbol Files](https://developer.apple.com/documentation/xcode/building-your-app-to-include-debugging-information)
- [Swift Package Manager dSYM Issues](https://developer.apple.com/forums/thread/665501)