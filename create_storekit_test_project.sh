#!/bin/bash

echo "🧪 Creating minimal StoreKit test project with Xcode..."

# Remove old test app if it exists
rm -rf StoreKitTestApp

# Create basic iOS project structure
mkdir -p StoreKitTestApp.xcodeproj
mkdir -p StoreKitTestApp

# Create minimal project.pbxproj
cat > StoreKitTestApp.xcodeproj/project.pbxproj << 'EOF'
// !$*UTF8*$!
{
	archiveVersion = 1;
	classes = {
	};
	objectVersion = 56;
	objects = {

/* Begin PBXBuildFile section */
		1A234567890A0001 /* StoreKitTestApp.swift in Sources */ = {isa = PBXBuildFile; fileRef = 1A234567890A0002 /* StoreKitTestApp.swift */; };
		1A234567890A0003 /* ContentView.swift in Sources */ = {isa = PBXBuildFile; fileRef = 1A234567890A0004 /* ContentView.swift */; };
		1A234567890A0025 /* EventAI.storekit in Resources */ = {isa = PBXBuildFile; fileRef = 1A234567890A0026 /* EventAI.storekit */; };
/* End PBXBuildFile section */

/* Begin PBXFileReference section */
		1A234567890A0000 /* StoreKitTestApp.app */ = {isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = StoreKitTestApp.app; sourceTree = BUILT_PRODUCTS_DIR; };
		1A234567890A0002 /* StoreKitTestApp.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = StoreKitTestApp.swift; sourceTree = "<group>"; };
		1A234567890A0004 /* ContentView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ContentView.swift; sourceTree = "<group>"; };
		1A234567890A0026 /* EventAI.storekit */ = {isa = PBXFileReference; lastKnownFileType = text.storekit; path = EventAI.storekit; sourceTree = "<group>"; };
/* End PBXFileReference section */

/* Begin PBXFrameworksBuildPhase section */
		1A234567890A0007 /* Frameworks */ = {
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
		1A234567890A0008 = {
			isa = PBXGroup;
			children = (
				1A234567890A0009 /* StoreKitTestApp */,
				1A234567890A0010 /* Products */,
			);
			sourceTree = "<group>";
		};
		1A234567890A0009 /* StoreKitTestApp */ = {
			isa = PBXGroup;
			children = (
				1A234567890A0002 /* StoreKitTestApp.swift */,
				1A234567890A0004 /* ContentView.swift */,
				1A234567890A0026 /* EventAI.storekit */,
			);
			path = StoreKitTestApp;
			sourceTree = "<group>";
		};
		1A234567890A0010 /* Products */ = {
			isa = PBXGroup;
			children = (
				1A234567890A0000 /* StoreKitTestApp.app */,
			);
			name = Products;
			sourceTree = "<group>";
		};
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
		1A234567890A0011 /* StoreKitTestApp */ = {
			isa = PBXNativeTarget;
			buildConfigurationList = 1A234567890A0012 /* Build configuration list for PBXNativeTarget "StoreKitTestApp" */;
			buildPhases = (
				1A234567890A0013 /* Sources */,
				1A234567890A0007 /* Frameworks */,
				1A234567890A0014 /* Resources */,
			);
			buildRules = (
			);
			dependencies = (
			);
			name = StoreKitTestApp;
			productName = StoreKitTestApp;
			productReference = 1A234567890A0000 /* StoreKitTestApp.app */;
			productType = "com.apple.product-type.application";
		};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
		1A234567890A0015 /* Project object */ = {
			isa = PBXProject;
			attributes = {
				BuildIndependentTargetsInParallel = 1;
				LastSwiftUpdateCheck = 1600;
				LastUpgradeCheck = 1600;
				TargetAttributes = {
					1A234567890A0011 = {
						CreatedOnToolsVersion = 16.0;
					};
				};
			};
			buildConfigurationList = 1A234567890A0016 /* Build configuration list for PBXProject "StoreKitTestApp" */;
			compatibilityVersion = "Xcode 14.0";
			developmentRegion = en;
			hasScannedForEncodings = 0;
			knownRegions = (
				en,
				Base,
			);
			mainGroup = 1A234567890A0008;
			productRefGroup = 1A234567890A0010 /* Products */;
			projectDirPath = "";
			projectRoot = "";
			targets = (
				1A234567890A0011 /* StoreKitTestApp */,
			);
		};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
		1A234567890A0014 /* Resources */ = {
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
				1A234567890A0025 /* EventAI.storekit in Resources */,
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
		1A234567890A0013 /* Sources */ = {
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
				1A234567890A0003 /* ContentView.swift in Sources */,
				1A234567890A0001 /* StoreKitTestApp.swift in Sources */,
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXSourcesBuildPhase section */

/* Begin XCBuildConfiguration section */
		1A234567890A0017 /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ALWAYS_SEARCH_USER_PATHS = NO;
				ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;
				CLANG_ANALYZER_NONNULL = YES;
				CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;
				CLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				CLANG_ENABLE_OBJC_WEAK = YES;
				CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES;
				CLANG_WARN_BOOL_CONVERSION = YES;
				CLANG_WARN_COMMA = YES;
				CLANG_WARN_CONSTANT_CONVERSION = YES;
				CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES;
				CLANG_WARN_DIRECT_OBJC_ISA_USAGE = YES_ERROR;
				CLANG_WARN_DOCUMENTATION_COMMENTS = YES;
				CLANG_WARN_EMPTY_BODY = YES;
				CLANG_WARN_ENUM_CONVERSION = YES;
				CLANG_WARN_INFINITE_RECURSION = YES;
				CLANG_WARN_INT_CONVERSION = YES;
				CLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;
				CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF = YES;
				CLANG_WARN_OBJC_LITERAL_CONVERSION = YES;
				CLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;
				CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES;
				CLANG_WARN_RANGE_LOOP_ANALYSIS = YES;
				CLANG_WARN_STRICT_PROTOTYPES = YES;
				CLANG_WARN_SUSPICIOUS_MOVE = YES;
				CLANG_WARN_UNGUARDED_AVAILABILITY = YES_AGGRESSIVE;
				CLANG_WARN_UNREACHABLE_CODE = YES;
				CLANG_WARN__DUPLICATE_METHOD_MATCH = YES;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = dwarf;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				ENABLE_TESTABILITY = YES;
				ENABLE_USER_SCRIPT_SANDBOXING = YES;
				GCC_C_LANGUAGE_STANDARD = gnu17;
				GCC_DYNAMIC_NO_PIC = NO;
				GCC_NO_COMMON_BLOCKS = YES;
				GCC_OPTIMIZATION_LEVEL = 0;
				GCC_PREPROCESSOR_DEFINITIONS = (
					"DEBUG=1",
					"$(inherited)",
				);
				GCC_WARN_64_TO_32_BIT_CONVERSION = YES;
				GCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;
				GCC_WARN_UNDECLARED_SELECTOR = YES;
				GCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;
				GCC_WARN_UNUSED_FUNCTION = YES;
				GCC_WARN_UNUSED_VARIABLE = YES;
				IPHONEOS_DEPLOYMENT_TARGET = 17.0;
				LOCALIZATION_PREFERS_STRING_CATALOGS = YES;
				MTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;
				MTL_FAST_MATH = YES;
				ONLY_ACTIVE_ARCH = YES;
				SDKROOT = iphoneos;
				SWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG $(inherited)";
				SWIFT_OPTIMIZATION_LEVEL = "-Onone";
			};
			name = Debug;
		};
		1A234567890A0018 /* Release */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ALWAYS_SEARCH_USER_PATHS = NO;
				ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;
				CLANG_ANALYZER_NONNULL = YES;
				CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;
				CLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				CLANG_ENABLE_OBJC_WEAK = YES;
				CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES;
				CLANG_WARN_BOOL_CONVERSION = YES;
				CLANG_WARN_COMMA = YES;
				CLANG_WARN_CONSTANT_CONVERSION = YES;
				CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES;
				CLANG_WARN_DIRECT_OBJC_ISA_USAGE = YES_ERROR;
				CLANG_WARN_DOCUMENTATION_COMMENTS = YES;
				CLANG_WARN_EMPTY_BODY = YES;
				CLANG_WARN_ENUM_CONVERSION = YES;
				CLANG_WARN_INFINITE_RECURSION = YES;
				CLANG_WARN_INT_CONVERSION = YES;
				CLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;
				CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF = YES;
				CLANG_WARN_OBJC_LITERAL_CONVERSION = YES;
				CLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;
				CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES;
				CLANG_WARN_RANGE_LOOP_ANALYSIS = YES;
				CLANG_WARN_STRICT_PROTOTYPES = YES;
				CLANG_WARN_SUSPICIOUS_MOVE = YES;
				CLANG_WARN_UNGUARDED_AVAILABILITY = YES_AGGRESSIVE;
				CLANG_WARN_UNREACHABLE_CODE = YES;
				CLANG_WARN__DUPLICATE_METHOD_MATCH = YES;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
				ENABLE_NS_ASSERTIONS = NO;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				ENABLE_USER_SCRIPT_SANDBOXING = YES;
				GCC_C_LANGUAGE_STANDARD = gnu17;
				GCC_NO_COMMON_BLOCKS = YES;
				GCC_WARN_64_TO_32_BIT_CONVERSION = YES;
				GCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;
				GCC_WARN_UNDECLARED_SELECTOR = YES;
				GCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;
				GCC_WARN_UNUSED_FUNCTION = YES;
				GCC_WARN_UNUSED_VARIABLE = YES;
				IPHONEOS_DEPLOYMENT_TARGET = 17.0;
				LOCALIZATION_PREFERS_STRING_CATALOGS = YES;
				MTL_ENABLE_DEBUG_INFO = NO;
				MTL_FAST_MATH = YES;
				SDKROOT = iphoneos;
				SWIFT_COMPILATION_MODE = wholemodule;
				VALIDATE_PRODUCT = YES;
			};
			name = Release;
		};
		1A234567890A0019 /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_TEAM = D8R2VUC2Y3;
				ENABLE_PREVIEWS = YES;
				GENERATE_INFOPLIST_FILE = YES;
				INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES;
				INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES;
				INFOPLIST_KEY_UILaunchScreen_Generation = YES;
				INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad = "UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
				INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone = "UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/Frameworks",
				);
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = "com.test.storekittest";
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_VERSION = 5.0;
				TARGETED_DEVICE_FAMILY = "1,2";
			};
			name = Debug;
		};
		1A234567890A0020 /* Release */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_TEAM = D8R2VUC2Y3;
				ENABLE_PREVIEWS = YES;
				GENERATE_INFOPLIST_FILE = YES;
				INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES;
				INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES;
				INFOPLIST_KEY_UILaunchScreen_Generation = YES;
				INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad = "UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
				INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone = "UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/Frameworks",
				);
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = "com.test.storekittest";
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_VERSION = 5.0;
				TARGETED_DEVICE_FAMILY = "1,2";
			};
			name = Release;
		};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
		1A234567890A0012 /* Build configuration list for PBXNativeTarget "StoreKitTestApp" */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
				1A234567890A0019 /* Debug */,
				1A234567890A0020 /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		};
		1A234567890A0016 /* Build configuration list for PBXProject "StoreKitTestApp" */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
				1A234567890A0017 /* Debug */,
				1A234567890A0018 /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		};
/* End XCConfigurationList section */
	};
	rootObject = 1A234567890A0015 /* Project object */;
}
EOF

# Create scheme with StoreKit configuration
mkdir -p StoreKitTestApp.xcodeproj/xcshareddata/xcschemes
cat > StoreKitTestApp.xcodeproj/xcshareddata/xcschemes/StoreKitTestApp.xcscheme << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<Scheme
   LastUpgradeVersion = "1600"
   version = "1.7">
   <BuildAction
      parallelizeBuildables = "YES"
      buildImplicitDependencies = "YES"
      buildArchitectures = "Automatic">
      <BuildActionEntries>
         <BuildActionEntry
            buildForTesting = "YES"
            buildForRunning = "YES"
            buildForProfiling = "YES"
            buildForArchiving = "YES"
            buildForAnalyzing = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "1A234567890A0011"
               BuildableName = "StoreKitTestApp.app"
               BlueprintName = "StoreKitTestApp"
               ReferencedContainer = "container:StoreKitTestApp.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      shouldUseLaunchSchemeArgsEnv = "YES"
      shouldAutocreateTestPlan = "YES">
      <StoreKitConfigurationFileReference
         identifier = "EventAI.storekit">
      </StoreKitConfigurationFileReference>
   </TestAction>
   <LaunchAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      launchStyle = "0"
      useCustomWorkingDirectory = "NO"
      ignoresPersistentStateOnLaunch = "NO"
      debugDocumentVersioning = "YES"
      debugServiceExtension = "internal"
      allowLocationSimulation = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "1A234567890A0011"
            BuildableName = "StoreKitTestApp.app"
            BlueprintName = "StoreKitTestApp"
            ReferencedContainer = "container:StoreKitTestApp.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
      <StoreKitConfigurationFileReference
         identifier = "EventAI.storekit">
      </StoreKitConfigurationFileReference>
   </LaunchAction>
   <ProfileAction
      buildConfiguration = "Release"
      shouldUseLaunchSchemeArgsEnv = "YES"
      savedToolIdentifier = ""
      useCustomWorkingDirectory = "NO"
      debugDocumentVersioning = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "1A234567890A0011"
            BuildableName = "StoreKitTestApp.app"
            BlueprintName = "StoreKitTestApp"
            ReferencedContainer = "container:StoreKitTestApp.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
      <StoreKitConfigurationFileReference
         identifier = "EventAI.storekit">
      </StoreKitConfigurationFileReference>
   </ProfileAction>
   <AnalyzeAction
      buildConfiguration = "Debug">
   </AnalyzeAction>
   <ArchiveAction
      buildConfiguration = "Release"
      revealArchiveInOrganizer = "YES">
   </AnalyzeAction>
</Scheme>
EOF

# Create App.swift
cat > StoreKitTestApp/StoreKitTestApp.swift << 'EOF'
import SwiftUI

@main
struct StoreKitTestApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
EOF

# Create ContentView.swift
cat > StoreKitTestApp/ContentView.swift << 'EOF'
import SwiftUI
import StoreKit

struct ContentView: View {
    @State private var products: [Product] = []
    @State private var status = "Ready to test"
    @State private var detailsVisible = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("🧪 StoreKit Test")
                .font(.title)
                .fontWeight(.bold)
            
            Text(status)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Test Product Loading") {
                Task {
                    await testProductLoading()
                }
            }
            .buttonStyle(.borderedProminent)
            
            if !products.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("✅ Products Found: \(products.count)")
                        .font(.headline)
                        .foregroundColor(.green)
                    
                    ForEach(products, id: \.id) { product in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(product.displayName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("ID: \(product.id)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("Price: \(product.displayPrice)")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                .padding(.horizontal)
            }
            
            Button("Show Technical Details") {
                detailsVisible.toggle()
            }
            .font(.caption)
            
            if detailsVisible {
                VStack(alignment: .leading, spacing: 5) {
                    Text("🔧 Technical Info:")
                        .font(.caption)
                        .fontWeight(.bold)
                    Text("• Bundle ID: com.test.storekittest")
                        .font(.caption2)
                    Text("• Team ID: D8R2VUC2Y3")
                        .font(.caption2)
                    Text("• StoreKit config: EventAI.storekit")
                        .font(.caption2)
                    Text("• Testing mode: Local configuration")
                        .font(.caption2)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal)
            }
        }
        .padding()
    }
    
    func testProductLoading() async {
        status = "🔄 Loading products..."
        
        do {
            print("📞 Calling Product.products(for:)")
            let productIDs = ["eventai_premium_monthly"]
            let loadedProducts = try await Product.products(for: productIDs)
            
            await MainActor.run {
                products = loadedProducts
                
                if loadedProducts.isEmpty {
                    status = "❌ No products found\n\nThis suggests StoreKit configuration is not being loaded properly in the test environment."
                } else {
                    status = "✅ Found \(loadedProducts.count) product(s)!\n\nStoreKit configuration is working correctly."
                    
                    for product in loadedProducts {
                        print("✅ Product: \(product.id) - \(product.displayName) - \(product.displayPrice)")
                    }
                }
            }
            
        } catch {
            await MainActor.run {
                status = "❌ Error: \(error.localizedDescription)\n\nThis indicates a StoreKit configuration or environment issue."
            }
            print("❌ StoreKit Error: \(error)")
        }
    }
}
EOF

# Copy our StoreKit configuration
cp EventAI.storekit StoreKitTestApp/

echo "✅ Complete StoreKit test project created!"
echo "📁 Location: StoreKitTestApp.xcodeproj"
echo "🎯 This project includes:"
echo "   - Proper Xcode project structure"
echo "   - StoreKit configuration in scheme"
echo "   - Same team ID as main app"
echo "   - Test bundle identifier"
echo ""
echo "📋 Next step: Build and run in simulator"