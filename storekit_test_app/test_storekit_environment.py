#!/usr/bin/env python3

import subprocess
import json
import os

def run_command(cmd):
    """Run a shell command and return output"""
    try:
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
        return result.stdout.strip(), result.stderr.strip(), result.returncode
    except Exception as e:
        return "", str(e), 1

def main():
    print("🧪 StoreKit Environment Diagnostic")
    print("=" * 50)
    
    # Check if we have the StoreKit file
    print("1. Checking StoreKit configuration file...")
    if os.path.exists("EventAI.storekit"):
        print("   ✅ EventAI.storekit found")
        try:
            with open("EventAI.storekit", "r") as f:
                config = json.load(f)
            print(f"   ✅ Valid JSON with {len(config.get('subscriptions', []))} subscriptions")
        except:
            print("   ❌ Invalid JSON format")
    else:
        print("   ❌ EventAI.storekit not found")
    
    # Check Xcode and simulator status
    print("\n2. Checking development environment...")
    
    stdout, stderr, code = run_command("xcodebuild -version")
    if code == 0:
        print(f"   ✅ Xcode: {stdout.split()[1] if stdout.split() else 'Unknown'}")
    else:
        print("   ❌ Xcode not found")
    
    stdout, stderr, code = run_command("xcrun simctl list devices | grep 'iPhone 16' | grep 'Booted'")
    if code == 0 and stdout:
        print("   ✅ iPhone 16 simulator is booted")
    else:
        print("   ⚠️  iPhone 16 simulator not booted")
    
    # Check for StoreKit testing documentation
    print("\n3. StoreKit testing requirements...")
    print("   📋 Based on Apple documentation:")
    print("      - StoreKit config file must be added to Xcode project")
    print("      - Scheme must reference the StoreKit config under 'Options'")
    print("      - App must run in simulator (not device) for local testing")
    print("      - StoreKit testing is only available in Xcode 12+")
    
    print("\n4. Possible issues with our setup...")
    print("   🔍 Common problems:")
    print("      - Scheme might not properly reference StoreKit config")
    print("      - StoreKit file might not be in the right location")
    print("      - App might be connecting to sandbox instead of local config")
    print("      - Bundle identifier mismatch")
    
    print("\n5. Debugging steps to try...")
    print("   🛠️  Next actions:")
    print("      1. Create minimal test app to isolate the issue")
    print("      2. Verify Xcode scheme configuration manually")
    print("      3. Check Xcode console for StoreKit-specific errors")
    print("      4. Test with different product IDs")
    print("      5. Verify simulator vs device behavior")
    
    print("\n" + "=" * 50)
    print("🏁 Diagnostic complete")

if __name__ == "__main__":
    main()