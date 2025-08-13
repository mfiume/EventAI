#!/usr/bin/env python3

import json
import sys

try:
    with open('EventAI.storekit', 'r') as f:
        config = json.load(f)
    
    print('🧪 StoreKit Configuration Analysis')
    print('=' * 40)
    
    # Check basic structure
    print(f'✅ Valid JSON format')
    print(f'📋 Identifier: {config.get("identifier", "N/A")}')
    print(f'📦 Products: {len(config.get("products", []))}')
    print(f'💰 Subscriptions: {len(config.get("subscriptions", []))}')
    
    # Analyze subscriptions
    subscriptions = config.get('subscriptions', [])
    if subscriptions:
        print('\n📊 Subscription Details:')
        for sub in subscriptions:
            localizations = sub.get('localizations', [{}])
            display_name = localizations[0].get('displayName', 'N/A') if localizations else 'N/A'
            
            print(f'   - Product ID: {sub.get("productID")}')
            print(f'   - Display Name: {display_name}')
            print(f'   - Price: ${sub.get("displayPrice")}')
            print(f'   - Type: {sub.get("type")}')
            print(f'   - Period: {sub.get("recurringSubscriptionPeriod")}')
    
    # Check settings
    settings = config.get('settings', {})
    print(f'\n⚙️  Settings:')
    print(f'   - Developer Team ID: {settings.get("_developerTeamID")}')
    print(f'   - App Internal ID: {settings.get("_applicationInternalID")}')
    print(f'   - Locale: {settings.get("_locale")}')
    print(f'   - Storefront: {settings.get("_storefront")}')
    
    # Check for common issues
    print(f'\n🔍 Validation Checks:')
    issues = []
    
    if not subscriptions:
        issues.append("No subscriptions defined")
    
    if settings.get("_developerTeamID") == "YourTeamID":
        issues.append("Developer Team ID is still placeholder")
    
    for sub in subscriptions:
        if not sub.get("productID"):
            issues.append("Subscription missing productID")
        if not sub.get("displayPrice"):
            issues.append("Subscription missing displayPrice")
    
    if issues:
        for issue in issues:
            print(f'   ⚠️  {issue}')
    else:
        print(f'   ✅ No issues found')
    
    print('\n✅ Configuration analysis complete!')
    
except json.JSONDecodeError as e:
    print(f'❌ JSON Error: {e}')
    sys.exit(1)
except Exception as e:
    print(f'❌ Error: {e}')
    sys.exit(1)