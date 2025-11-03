import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var apiService: SharedAPIService
    @StateObject private var subscriptionService = RevenueCatService_macOS.shared
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("showMenuBarIcon") private var showMenuBarIcon = true
    @AppStorage("enableNotifications") private var enableNotifications = true
    @AppStorage("defaultEventDuration") private var defaultEventDuration = 60
    @AppStorage("alwaysOnTop") private var alwaysOnTop = false
    @AppStorage("autoAddToCalendar") private var autoAddToCalendar = false
    @AppStorage("preferredCalendarName") private var preferredCalendarName = ""
    
    private let durationOptions = [15, 30, 60, 90, 120]
    
    var body: some View {
        TabView {
            // General Settings
            VStack(alignment: .leading, spacing: 20) {
                SettingsSection("Appearance") {
                    Toggle("Show menu bar icon", isOn: $showMenuBarIcon)
                        .onChange(of: showMenuBarIcon) { newValue in
                            NotificationCenter.default.post(
                                name: .toggleMenuBar,
                                object: nil,
                                userInfo: ["show": newValue]
                            )
                        }
                    
                    Toggle("Always on top", isOn: $alwaysOnTop)
                        .onChange(of: alwaysOnTop) { newValue in
                            NotificationCenter.default.post(
                                name: .toggleAlwaysOnTop,
                                object: nil,
                                userInfo: ["enabled": newValue]
                            )
                        }
                }
                
                SettingsSection("Startup") {
                    Toggle("Launch EventAI at login", isOn: $launchAtLogin)
                        .onChange(of: launchAtLogin) { newValue in
                            setLaunchAtLogin(newValue)
                        }
                }
                
                SettingsSection("Notifications") {
                    Toggle("Enable notifications", isOn: $enableNotifications)
                    
                    Text("Get notified when events are successfully added to your calendar.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding()
            .tabItem {
                Label("General", systemImage: "gear")
            }
            
            // Calendar Settings
            VStack(alignment: .leading, spacing: 20) {
                SettingsSection("Event Defaults") {
                    HStack {
                        Text("Default event duration:")
                        Spacer()
                        Picker("Duration", selection: $defaultEventDuration) {
                            ForEach(durationOptions, id: \.self) { duration in
                                Text("\(duration) min").tag(duration)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 100)
                    }
                    
                    Toggle("Auto-add events to calendar", isOn: $autoAddToCalendar)
                    
                    HStack {
                        Text("Preferred calendar:")
                        Spacer()
                        TextField("Calendar name", text: $preferredCalendarName)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 150)
                    }
                }
                
                SettingsSection("Calendar Permissions") {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Calendar Access")
                                .font(.headline)
                            
                            Text("EventAI needs calendar access to create events.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if SharedCalendarService.shared.hasCalendarAccess {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.title2)
                        } else {
                            Button("Grant Access") {
                                Task {
                                    await SharedCalendarService.shared.requestAccess()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
            .tabItem {
                Label("Calendar", systemImage: "calendar")
            }
            
            // Premium & Subscription
            VStack(alignment: .leading, spacing: 20) {
                SettingsSection("Subscription Status") {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(subscriptionService.subscriptionStatus)
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundColor(subscriptionService.isPremium ? .green : .primary)
                                
                                if subscriptionService.isPremium {
                                    Image(systemName: "crown.fill")
                                        .foregroundColor(.yellow)
                                }
                            }
                            
                            if let expiryDate = subscriptionService.expiryDate {
                                Text("Expires: \(expiryDate, formatter: subscriptionDateFormatter)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Text(subscriptionService.isPremium ? "Unlimited daily conversions" : "3 daily conversions")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        VStack(spacing: 8) {
                            if !subscriptionService.isPremium {
                                Button("Upgrade to Premium") {
                                    Task {
                                        await subscriptionService.purchaseSubscription()
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(subscriptionService.isLoading)
                                
                                Button("Restore Purchases") {
                                    Task {
                                        await subscriptionService.restorePurchases()
                                    }
                                }
                                .buttonStyle(.bordered)
                                .disabled(subscriptionService.isLoading)
                            } else {
                                Button("Manage Subscription") {
                                    subscriptionService.showCustomerCenter()
                                }
                                .buttonStyle(.bordered)
                                
                                Button("Sync with Other Devices") {
                                    Task {
                                        await subscriptionService.syncWithOtherPlatforms()
                                    }
                                }
                                .buttonStyle(.borderless)
                                .disabled(subscriptionService.isLoading)
                            }
                        }
                    }
                    
                    if let error = subscriptionService.purchaseError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.top, 4)
                    }
                    
                    if subscriptionService.isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                            .padding(.top, 4)
                    }
                }
                
                SettingsSection("Cross-Platform Sync") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your subscription works on all your devices")
                            .font(.subheadline)
                        
                        Text("Subscribe on iOS, unlock on macOS - or vice versa. Your premium status is automatically synced across all platforms where you're signed in with the same Apple ID.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Image(systemName: "iphone")
                            Image(systemName: "arrow.left.arrow.right")
                            Image(systemName: "laptopcomputer")
                        }
                        .font(.title2)
                        .foregroundColor(.blue)
                        .padding(.top, 4)
                    }
                }
                
                Spacer()
            }
            .padding()
            .tabItem {
                Label("Premium", systemImage: "crown")
            }
            
            // API Settings
            VStack(alignment: .leading, spacing: 20) {
                SettingsSection("API Configuration") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("API Status:")
                            Spacer()
                            
                            Circle()
                                .fill(Color.green)
                                .frame(width: 8, height: 8)
                            
                            Text("Connected")
                                .font(.caption)
                        }
                        
                        Text("Base URL: eventai.leveluplife.app")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                SettingsSection("Usage & Limits") {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Daily Usage")
                                .font(.headline)
                            
                            Text("Track your API usage and limits")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button("Check Usage") {
                            Task {
                                do {
                                    let _ = try await apiService.getUsage()
                                } catch {
                                    print("Failed to fetch usage: \(error)")
                                }
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                }
                
                Spacer()
            }
            .padding()
            .tabItem {
                Label("API", systemImage: "network")
            }
            
            // About
            VStack(spacing: 20) {
                Image(systemName: "calendar.badge.plus")
                    .font(.system(size: 64))
                    .foregroundColor(.blue)
                
                VStack(spacing: 8) {
                    Text("EventAI for macOS")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Version 1.0.0")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("Create calendar events from natural language using AI")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                VStack(spacing: 12) {
                    Button("View on GitHub") {
                        if let url = URL(string: "https://github.com/EventAI/EventAI") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Visit Website") {
                        if let url = URL(string: "https://eventai.leveluplife.app") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(.blue)
                }
                
                Spacer()
                
                Text("© 2024 EventAI. All rights reserved.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .tabItem {
                Label("About", systemImage: "info.circle")
            }
        }
        .frame(width: 500, height: 400)
    }
    
    // MARK: - Helper Functions
    private func setLaunchAtLogin(_ enabled: Bool) {
        // This would need to be implemented with proper macOS launch services
        // For now, just store the preference
        print("Launch at login: \(enabled)")
    }
    
    private var subscriptionDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }
}

// MARK: - Settings Section Helper
struct SettingsSection<Content: View>: View {
    let title: String
    let content: () -> Content
    
    init(_ title: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(alignment: .leading, spacing: 8) {
                content()
            }
            .padding(.leading, 8)
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(SharedAPIService.shared)
}