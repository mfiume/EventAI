import SwiftUI
import EventKit
import CoreLocation

struct ContentView: View {
    @State private var inputText = ""
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var showAdBanner = true
    @State private var selectedTimezone = TimeZone.current
    @State private var useLocationForTimezone = false // TEMPORARILY DISABLED for AI address testing
    @State private var showEventPreview = false
    @State private var currentEvents: [ParsedEvent] = []
    @State private var currentICSContent = ""
    @State private var dailyConversionsUsed = 0
    @State private var dailyLimit = 100  // Updated to match backend testing limits
    @State private var premiumDailyLimit = 200  // Updated to match backend testing limits
    @State private var canConvert = true
    @State private var isLoadingUsage = true
    @State private var selectedImage: UIImage?
    @State private var showingImagePicker = false
    @State private var imageSourceType: UIImagePickerController.SourceType = .photoLibrary
    @State private var showingPremiumModal = false
    @FocusState private var isTextFieldFocused: Bool
    @StateObject private var apiService = APIService()
    @StateObject private var calendarService = CalendarService()
    @StateObject private var adService = AdService()
    @StateObject private var locationService = LocationService()
    @StateObject private var subscriptionService = SubscriptionService()
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Usage indicator for free users (always show with skeleton loader)
                if !subscriptionService.isPremium {
                    UsageIndicatorView(subscriptionService: subscriptionService, showingPremiumModal: $showingPremiumModal, dailyConversionsUsed: dailyConversionsUsed, dailyLimit: dailyLimit, isLoading: isLoadingUsage)
                }
                
                inputSection
                
                Spacer()
                
                // AdMob banner for free users
                if !subscriptionService.isPremium && adService.isAdLoaded {
                    adService.loadBannerAd()
                        .frame(height: 60)
                        .cornerRadius(8)
                        .padding(.horizontal, -16) // Extend to screen edges
                }
            }
            .padding()
            .navigationTitle("EventAI")
            .navigationBarTitleDisplayMode(.inline)
            #if DEBUG
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    NavigationLink("🧪 Test") {
                        // TODO: Uncomment when SubscriptionTestView is added to Xcode project
                        Text("RevenueCat Test Coming Soon")
                            .padding()
                        // SubscriptionTestView()
                    }
                    .font(.caption)
                }
            }
            #endif
            .onTapGesture {
                // Remove focus and dismiss keyboard when tapping outside text field
                isTextFieldFocused = false
            }
            .alert("EventAI", isPresented: $showAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
            .sheet(isPresented: $showEventPreview) {
                EventPreviewView(
                    events: currentEvents,
                    icsContent: currentICSContent,
                    calendarService: calendarService,
                    subscriptionService: subscriptionService,
                    userTimezone: useLocationForTimezone && locationService.inferredTimezone != nil ? locationService.inferredTimezone! : selectedTimezone,
                    onEventsAdded: { addedCount in
                        // Clear input and show success state
                        clearAll()
                        showEventPreview = false
                    }
                )
            }
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(image: $selectedImage, sourceType: imageSourceType)
            }
            .fullScreenCover(isPresented: $showingPremiumModal) {
                // Light-themed Premium Modal
                GeometryReader { geometry in
                    ZStack {
                        // Light gradient background
                        LinearGradient(
                            colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1), Color.white],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .ignoresSafeArea(.all)
                        
                        // Light overlay
                        Color.white.opacity(0.9)
                            .ignoresSafeArea(.all)
                        
                        // Close button positioned absolutely at top-right
                        VStack {
                            HStack {
                                Spacer()
                                Button(action: { showingPremiumModal = false }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 28))
                                        .foregroundColor(.gray)
                                        .background(Color.white)
                                        .clipShape(Circle())
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                            
                            Spacer()
                        }
                        
                        // Main content
                        VStack(spacing: 32) {
                            Spacer()
                                .frame(height: 100)
                            
                            Spacer()
                            
                            VStack(spacing: 24) {
                                Text("Upgrade to Premium")
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundColor(.primary)
                                
                                Image(systemName: "calendar.badge.plus")
                                    .font(.system(size: 80))
                                    .foregroundColor(.blue)
                                
                                VStack(spacing: 8) {
                                    Text("Get more conversions, remove ads, and unlock priority processing for your events.")
                                        .font(.system(size: 16))
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                        .lineLimit(4)
                                        .fixedSize(horizontal: false, vertical: true)
                                    
                                    // Show upgrade comparison if user is on free tier
                                    if !subscriptionService.isPremium && dailyLimit > 0 && premiumDailyLimit > dailyLimit {
                                        Text("Upgrade from \(dailyLimit) to \(premiumDailyLimit) daily conversions")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.blue)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 4)
                                            .background(Color.blue.opacity(0.1))
                                            .cornerRadius(8)
                                    }
                                }
                                
                                VStack(spacing: 12) {
                                    HStack(spacing: 12) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 16))
                                            .foregroundColor(.green)
                                        Text("More Conversions (\(premiumDailyLimit) Per Day)")
                                            .font(.system(size: 16))
                                            .foregroundColor(.primary)
                                        Spacer()
                                    }
                                    HStack(spacing: 12) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 16))
                                            .foregroundColor(.green)
                                        Text("Photo Support")
                                            .font(.system(size: 16))
                                            .foregroundColor(.primary)
                                        Spacer()
                                    }
                                    HStack(spacing: 12) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 16))
                                            .foregroundColor(.green)
                                        Text("Ad-Free")
                                            .font(.system(size: 16))
                                            .foregroundColor(.primary)
                                        Spacer()
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                            
                            Spacer()
                            
                            VStack(spacing: 16) {
                                Button(action: {
                                    Task {
                                        await subscriptionService.purchaseSubscription()
                                        if subscriptionService.isPremium {
                                            showingPremiumModal = false
                                        }
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: "crown.fill")
                                            .font(.system(size: 16))
                                            .foregroundColor(.white)
                                        Text("Upgrade to Premium")
                                            .font(.system(size: 18, weight: .semibold))
                                            .foregroundColor(.white)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(.blue)
                                    )
                                }
                                
                                Text("$4.99/month • Cancel anytime")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 40)
                        }
                    }
                }
            }
        }
        .onAppear {
            calendarService.requestCalendarAccess()
            adService.initializeAds()
            Task {
                await loadUsageFromBackend()
            }
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                Task {
                    await loadUsageFromBackend()
                }
            }
        }
    }
    
    
    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Text input with integrated attachment and clear buttons
            ZStack(alignment: .topLeading) {
                VStack(spacing: 0) {
                    TextEditor(text: $inputText)
                        .frame(minHeight: 120)
                        .padding(.horizontal, 12)
                        .padding(.top, 12)
                        .padding(.bottom, 44) // Extra space for bottom toolbar
                        .background(Color.white)
                        .focused($isTextFieldFocused)
                    
                    // Bottom toolbar with attachment, location, and clear buttons
                    HStack {
                        // Attachment button (paperclip) - blue when attachment is present
                        Menu {
                            Button(action: {
                                imageSourceType = .photoLibrary
                                showingImagePicker = true
                            }) {
                                HStack {
                                    Text("Choose Photo")
                                    Spacer()
                                    Image(systemName: "photo")
                                }
                            }
                            
                            Button(action: {
                                imageSourceType = .camera
                                showingImagePicker = true
                            }) {
                                HStack {
                                    Text("Take Photo")
                                    Spacer()
                                    Image(systemName: "camera")
                                }
                            }
                        } label: {
                            Image(systemName: "paperclip")
                                .font(.system(size: 18))
                                .foregroundColor(selectedImage != nil ? .blue : .gray.opacity(0.7))
                                .padding(8)
                        }
                        
                        // Location services toggle button - TEMPORARILY HIDDEN for AI address testing
                        // TODO: Re-enable after testing AI's address finding capabilities
                        /*
                        Button(action: {
                            useLocationForTimezone.toggle()
                            // Remove focus and dismiss keyboard when toggle changes
                            isTextFieldFocused = false
                            if useLocationForTimezone && !locationService.isLocationEnabled {
                                locationService.requestLocationPermission()
                            }
                        }) {
                            Image(systemName: useLocationForTimezone ? "location.fill" : "location")
                                .font(.system(size: 18))
                                .foregroundColor(useLocationForTimezone ? .blue : .gray.opacity(0.7))
                                .padding(8)
                        }
                        */
                        
                        // Timezone display (always show)
                        NavigationLink(destination: TimezonePickerView(selectedTimezone: $selectedTimezone)) {
                            Text(timezoneShorthand)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(4)
                        }
                        
                        Spacer()
                        
                        // Clear text button (only show when there's text)
                        if !inputText.isEmpty {
                            Button(action: {
                                inputText = ""
                                // Remove focus and dismiss keyboard
                                isTextFieldFocused = false
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.gray.opacity(0.6))
                                    .padding(8)
                            }
                        }
                        
                        // Generate button - send arrow (similar to iMessage)
                        Button(action: generateCalendarEvents) {
                            ZStack {
                                if isLoading {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                        .tint(.white)
                                } else {
                                    Image(systemName: "arrow.up.circle.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor((hasContent && !isLoadingUsage) ? .blue : .gray.opacity(0.5))
                                }
                            }
                            .frame(width: 24, height: 24)
                            .background(isLoading ? Color.blue : Color.clear)
                            .clipShape(Circle())
                        }
                        .disabled(!hasContent || isLoading || isLoadingUsage)
                        .padding(.leading, 4)
                        .padding(.trailing, 8)
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)
                    .background(Color.white)
                }
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                
                if inputText.isEmpty && selectedImage == nil && !isTextFieldFocused {
                    Text("Use AI to create calendar events from text and images")
                        .foregroundColor(.gray.opacity(0.6))
                        .font(.body)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 20)
                        .allowsHitTesting(false)
                }
            }
            
            // Show attached image with close button
            if let image = selectedImage {
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 100)
                        .cornerRadius(8)
                        .shadow(radius: 2)
                    
                    // Close button
                    Button(action: {
                        selectedImage = nil
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.gray.opacity(0.6))
                            .background(Color.white)
                            .clipShape(Circle())
                    }
                    .offset(x: -4, y: 4)
                }
                .padding(.vertical, 4)
            }
            
            
            // Examples section - elegant design
            if inputText.isEmpty && selectedImage == nil {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Try these examples")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(spacing: 8) {
                        ExampleButton(
                            icon: "calendar.badge.clock",
                            text: "Dentist appointment tomorrow at 2pm",
                            onTap: { inputText = "Dentist appointment tomorrow at 2pm" }
                        )
                        
                        ExampleButton(
                            icon: "repeat",
                            text: "Weekly team meeting every Monday 9-10 AM",
                            onTap: { inputText = "Weekly team meeting every Monday 9-10 AM" }
                        )
                        
                        // Temporary replacement example (location example hidden during AI address testing)
                        ExampleButton(
                            icon: "phone",
                            text: "Video call with Sarah next Friday 1-2 PM",
                            onTap: { inputText = "Video call with Sarah next Friday 1-2 PM" }
                        )
                    }
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.blue.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.blue.opacity(0.1), lineWidth: 1)
                        )
                )
            }
            
        }
    }
    
    
    
    // Helper computed property to check if there's any content
    private var hasContent: Bool {
        return !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedImage != nil
    }
    
    // Helper computed property for timezone shorthand
    private var timezoneShorthand: String {
        let abbreviation = selectedTimezone.abbreviation() ?? selectedTimezone.identifier
        // If abbreviation is still long, try to extract a shorter version
        if abbreviation.count > 5 {
            // Try common timezone mapping
            let identifier = selectedTimezone.identifier
            if identifier.contains("New_York") { return "EST" }
            if identifier.contains("Chicago") { return "CST" }
            if identifier.contains("Denver") { return "MST" }
            if identifier.contains("Los_Angeles") { return "PST" }
            if identifier.contains("London") { return "GMT" }
            if identifier.contains("Tokyo") { return "JST" }
            if identifier.contains("Sydney") { return "AEDT" }
            if identifier.contains("Toronto") { return "EST" }
            // Fallback to last part of identifier without underscores
            let lastPart = identifier.components(separatedBy: "/").last?.replacingOccurrences(of: "_", with: " ") ?? "UTC"
            return String(lastPart.prefix(8)) // Allow longer for readable names like "New York"
        }
        return abbreviation.replacingOccurrences(of: "_", with: " ")
    }
    
    private func clearAll() {
        inputText = ""
        selectedImage = nil
        // Remove focus and dismiss keyboard
        isTextFieldFocused = false
    }
    
    @MainActor
    private func loadUsageFromBackend() async {
        isLoadingUsage = true
        do {
            let usageResponse = try await apiService.getUsageStats()
            dailyConversionsUsed = usageResponse.count
            dailyLimit = usageResponse.limit
            canConvert = usageResponse.canConvert
            
            // For premium modal, we need both current limit and premium limit
            // If user is currently premium, they already have the premium limit
            // If user is free, we need to show what premium limit would be
            if subscriptionService.isPremium {
                premiumDailyLimit = usageResponse.limit // They already have premium limit
            } else {
                // For free users, premium limit should be higher than their current limit
                // We can infer this from the API structure or use a reasonable premium amount
                premiumDailyLimit = usageResponse.limit < 100 ? 20 : 200 // Handle testing vs production
            }
            
            print("📊 Usage loaded: \(usageResponse.remaining) of \(usageResponse.limit) remaining, premium would be \(premiumDailyLimit)")
        } catch {
            print("❌ Failed to load usage: \(error)")
            // Keep existing stats on error
        }
        isLoadingUsage = false
    }
    
    @MainActor
    private func refreshUsageFromBackend() async {
        // Refresh usage without showing skeleton loader (for post-conversion updates)
        do {
            let usageResponse = try await apiService.getUsageStats()
            dailyConversionsUsed = usageResponse.count
            dailyLimit = usageResponse.limit
            canConvert = usageResponse.canConvert
            
            print("📊 Usage refreshed: \(usageResponse.remaining) of \(usageResponse.limit) remaining")
        } catch {
            print("❌ Failed to refresh usage: \(error)")
            // Keep existing stats on error
        }
    }
    
    private func generateCalendarEvents() {
        Task {
            await performGenerateCalendarEvents()
        }
    }
    
    private func performGenerateCalendarEvents() async {
        guard hasContent else { return }
        
        // Remove focus and dismiss keyboard when generating events
        isTextFieldFocused = false
        
        // Check usage limits for non-premium users using cached data
        let isPremium = subscriptionService.isPremium
        if !isPremium {
            let remaining = max(0, dailyLimit - dailyConversionsUsed)
            
            // Trust the cached usage count - if it shows 0 remaining, show premium modal
            if remaining == 0 {
                await MainActor.run {
                    showingPremiumModal = true
                }
                return
            }
            // If remaining > 0, proceed with conversion - backend will handle if somehow usage is actually exhausted
        }
        
        await MainActor.run {
            isLoading = true
        }
        
        if !isPremium {
            // Show AdMob interstitial for free users
            await MainActor.run {
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first,
                   let rootViewController = window.rootViewController {
                    adService.showInterstitialAd(from: rootViewController) {
                        Task {
                            await self.performEventGeneration()
                        }
                    }
                } else {
                    Task {
                        await self.performEventGeneration()
                    }
                }
            }
            return
        }
        
        // Premium users skip the ad
        await performEventGeneration()
    }
    
    private func performEventGeneration() async {
        do {
                // Determine effective timezone and location
                let effectiveTimezone = useLocationForTimezone && locationService.inferredTimezone != nil 
                    ? locationService.inferredTimezone! 
                    : selectedTimezone
                
                let userLocation = (useLocationForTimezone && locationService.isLocationEnabled) ? locationService.locationString : nil
                
                // Prepare text with image context if image is attached
                var finalText = inputText
                if selectedImage != nil {
                    if finalText.isEmpty {
                        finalText = "Please analyze this image and create calendar events from any schedule, meeting, or event information you can see."
                    } else {
                        finalText += "\n\n[Image attached - please analyze the image for additional schedule information]"
                    }
                }
                
                let response = try await apiService.convertTextToCalendar(
                    text: finalText,
                    timezone: effectiveTimezone.identifier,
                    userLocation: userLocation,
                    image: selectedImage
                )
                
                await MainActor.run {
                    isLoading = false
                    
                    if response.eventsFound > 0 && response.events != nil && !response.events!.isEmpty {
                        // Show event preview instead of immediate calendar addition
                        currentEvents = response.events ?? []
                        currentICSContent = response.icsContent
                        showEventPreview = true
                        
                        // Refresh usage stats after successful conversion (without skeleton loader)
                        if !subscriptionService.isPremium {
                            Task {
                                await refreshUsageFromBackend()
                            }
                        }
                    } else {
                        // Only show error alerts for actual API/technical errors, not "no events found" 
                        // For "no events found", just do nothing - user can try again
                        if !response.message.lowercased().contains("no events") && 
                           !response.message.lowercased().contains("couldn't find") &&
                           !response.message.lowercased().contains("no calendar events") {
                            alertMessage = response.message
                            showAlert = true
                        }
                    }
                }
        } catch {
            await MainActor.run {
                isLoading = false
                alertMessage = "Error: \(error.localizedDescription)"
                showAlert = true
            }
        }
    }
    
    // Common timezones for the picker
    private var commonTimezones: [TimeZone] {
        let identifiers = [
            "America/New_York",    // Eastern Time
            "America/Chicago",     // Central Time
            "America/Denver",      // Mountain Time
            "America/Los_Angeles", // Pacific Time
            "Europe/London",       // GMT/BST
            "Europe/Paris",        // CET/CEST
            "Europe/Berlin",       // CET/CEST
            "Asia/Tokyo",          // JST
            "Asia/Shanghai",       // CST
            "Australia/Sydney",    // AEST/AEDT
            "UTC"                  // UTC
        ]
        
        return identifiers.compactMap { TimeZone(identifier: $0) }
    }
}

// MARK: - Timezone picker now in separate file

// MARK: - Location Service
@MainActor

// MARK: - Event Preview View
struct EventPreviewView: View {
    let events: [ParsedEvent]
    let icsContent: String
    let calendarService: CalendarService
    @ObservedObject var subscriptionService: SubscriptionService
    let userTimezone: TimeZone
    let onEventsAdded: (Int) -> Void
    
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedEvents: Set<UUID> = []
    @State private var selectedCalendar: EKCalendar?
    @State private var showingCalendarPicker = false
    @State private var showingCelebration = false
    @State private var celebrationScale: CGFloat = 0
    @State private var celebrationRotation: Double = 0
    @State private var celebrationOpacity: Double = 0
    @State private var confettiTrigger: Int = 0
    @State private var showingShareSheet = false
    
    init(events: [ParsedEvent], icsContent: String, calendarService: CalendarService, subscriptionService: SubscriptionService, userTimezone: TimeZone, onEventsAdded: @escaping (Int) -> Void) {
        self.events = events
        self.icsContent = icsContent
        self.calendarService = calendarService
        self.subscriptionService = subscriptionService
        self.userTimezone = userTimezone
        self.onEventsAdded = onEventsAdded
        // Select all events by default
        _selectedEvents = State(initialValue: Set(events.map { $0.id }))
        // Use default calendar initially
        _selectedCalendar = State(initialValue: calendarService.getDefaultCalendar())
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        // Summary info with select all button
                        HStack {
                            Image(systemName: "calendar.circle.fill")
                                .font(.title3)
                                .foregroundColor(.blue)
                            
                            Text("Found \(events.count) Event\(events.count == 1 ? "" : "s")")
                                .font(.headline)
                                .fontWeight(.medium)
                            
                            Spacer()
                            
                            // Select/Deselect All Button
                            Button(action: {
                                if selectedEvents.count == events.count {
                                    selectedEvents.removeAll()
                                } else {
                                    selectedEvents = Set(events.map { $0.id })
                                }
                            }) {
                                Text(selectedEvents.count == events.count ? "Deselect All" : "Select All")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.blue)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(6)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                        
                        // Calendar Selection
                        if !calendarService.availableCalendars.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "folder.badge.plus")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                    
                                    Text("Add to Calendar:")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                }
                                
                                Button(action: { showingCalendarPicker = true }) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(selectedCalendar?.title ?? "Default Calendar")
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                                .foregroundColor(.primary)
                                            
                                            if let source = selectedCalendar?.source {
                                                Text(source.title)
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        
                                        Spacer()
                                        
                                        Image(systemName: "chevron.down")
                                            .font(.caption)
                                            .foregroundColor(.blue)
                                    }
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 12)
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(8)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 8)
                        }
                        
                        // Events with interspersed ads for free users
                        ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                            EventCard(
                                event: event,
                                isSelected: selectedEvents.contains(event.id)
                            ) {
                                toggleEventSelection(event.id)
                            }
                            
                            // Add banner ad every 3 events for free users
                            if !subscriptionService.isPremium && (index + 1) % 3 == 0 && index < events.count - 1 {
                                BannerAdView()
                                    .frame(height: 60)
                                    .padding(.vertical, 8)
                            }
                        }
                        
                        // Add some bottom padding for the floating button
                        Rectangle()
                            .fill(Color.clear)
                            .frame(height: 100)
                    }
                    .padding(.horizontal)
                }
                
                // Floating Add to Calendar Button
                VStack {
                    Spacer()
                    addToCalendarButton
                }
                
                // Celebration Overlay
                if showingCelebration {
                    celebrationOverlay
                }
            }
            .navigationTitle("Events")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button(action: { shareICSFile() }) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 18))
                }
            )
            .sheet(isPresented: $showingCalendarPicker) {
                CalendarPickerView(
                    availableCalendars: calendarService.availableCalendars,
                    selectedCalendar: $selectedCalendar
                )
            }
            .sheet(isPresented: $showingShareSheet) {
                ShareSheet(activityItems: [createICSFileForSelectedEvents()])
            }
        }
    }
    
    
    private var addToCalendarButton: some View {
        Button(action: addSelectedEventsToCalendar) {
            HStack {
                Image(systemName: "calendar.badge.plus")
                Text("Add \(selectedEvents.count) Event\(selectedEvents.count == 1 ? "" : "s") to Calendar")
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 25)
                    .fill(selectedEvents.isEmpty ? Color.gray : Color.blue)
            )
            .scaleEffect(selectedEvents.isEmpty ? 0.9 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: selectedEvents.count)
        }
        .disabled(selectedEvents.isEmpty)
        .padding(.horizontal)
        .padding(.bottom, 30)
    }
    
    private var celebrationOverlay: some View {
        ZStack {
            // Softer, lighter background with blur effect
            Color.white.opacity(0.95)
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                // Main celebration icon - blue with white background circle
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 140, height: 140)
                        .shadow(color: .blue.opacity(0.3), radius: 20, x: 0, y: 10)
                    
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 100))
                        .foregroundColor(.blue)
                        .scaleEffect(celebrationScale)
                        .rotationEffect(.degrees(celebrationRotation))
                }
                
                // Success message with better contrast
                VStack(spacing: 12) {
                    Text("🎉 Success!")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("Added \(selectedEvents.count) event\(selectedEvents.count == 1 ? "" : "s") to your calendar")
                        .font(.title2)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
                .opacity(celebrationOpacity)
                
                // Enhanced confetti effect with more variety
                ForEach(0..<20, id: \.self) { i in
                    let shapes = ["circle.fill", "star.fill", "heart.fill", "diamond.fill"]
                    let colors: [Color] = [.blue, .purple, .pink, .orange, .yellow, .green]
                    
                    Image(systemName: shapes.randomElement() ?? "circle.fill")
                        .font(.system(size: CGFloat.random(in: 8...16)))
                        .foregroundColor(colors.randomElement() ?? .blue)
                        .offset(
                            x: CGFloat.random(in: -150...150),
                            y: CGFloat.random(in: -250...50)
                        )
                        .opacity(celebrationOpacity * 0.8)
                        .scaleEffect(CGFloat.random(in: 0.5...1.5))
                        .rotationEffect(.degrees(Double.random(in: 0...360)))
                        .animation(
                            .easeOut(duration: Double.random(in: 1.5...3.0))
                                .delay(Double.random(in: 0...0.8)),
                            value: confettiTrigger
                        )
                }
                
                // Subtle pulse effect background
                Circle()
                    .stroke(Color.blue.opacity(0.3), lineWidth: 2)
                    .frame(width: 200, height: 200)
                    .scaleEffect(celebrationScale * 1.5)
                    .opacity(celebrationOpacity * 0.5)
                    .animation(.easeOut(duration: 2.0), value: confettiTrigger)
            }
        }
    }
    
    private func toggleEventSelection(_ eventId: UUID) {
        if selectedEvents.contains(eventId) {
            selectedEvents.remove(eventId)
        } else {
            selectedEvents.insert(eventId)
        }
    }
    
    private func addSelectedEventsToCalendar() {
        // Create ICS content with only selected events
        // For now, we'll use all events - in a real implementation, 
        // you'd filter the ICS content to only include selected events
        
        calendarService.addEventsToCalendar(icsContent: icsContent, selectedCalendar: selectedCalendar, userTimezone: userTimezone) { success, error in
            DispatchQueue.main.async {
                if success {
                    // Start celebration animation
                    startCelebration()
                } else {
                    // Handle error - could show a toast or alert
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
    }
    
    private func startCelebration() {
        showingCelebration = true
        confettiTrigger += 1
        
        // Start with initial state
        celebrationScale = 0.1
        celebrationRotation = 0
        celebrationOpacity = 0
        
        // Animate in sequence for smooth flow
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            celebrationScale = 1.0
            celebrationOpacity = 1.0
        }
        
        // Add rotation after initial scale
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.easeInOut(duration: 0.8)) {
                celebrationRotation = 360
            }
        }
        
        // Auto-dismiss with better timing
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.easeOut(duration: 0.4)) {
                celebrationOpacity = 0
                celebrationScale = 0.8
            }
            
            // Ensure clean dismissal
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showingCelebration = false
                onEventsAdded(selectedEvents.count)
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
    
    private func shareICSFile() {
        showingShareSheet = true
    }
    
    private func createICSFileForSelectedEvents() -> URL {
        // Filter ICS content to only include selected events
        // For now, we'll use the full ICS content
        // In a complete implementation, we would parse and filter the ICS content
        
        let fileName = "EventAI-Events.ics"
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsPath.appendingPathComponent(fileName)
        
        do {
            try icsContent.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            print("Error writing ICS file: \(error)")
        }
        
        return fileURL
    }
}

// MARK: - Event Card View
struct EventCard: View {
    let event: ParsedEvent
    let isSelected: Bool
    let onTap: () -> Void
    
    @State private var showingOccurrences = false
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Selection indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(isSelected ? .blue : .gray)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
                
                VStack(alignment: .leading, spacing: 12) {
                    // Header: Title only
                    HStack {
                        Text(event.title)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Spacer()
                    }
                    
                    // Enhanced recurring badge with comprehensive info
                    if event.isRecurring {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                                Text(formatEnhancedRecurrenceBadge(event))
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                                    .fontWeight(.medium)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.orange.opacity(0.15))
                            .cornerRadius(6)
                        }
                    }
                    
                    // Time and timezone info - REQUIRED for ICS
                    if let startDate = event.formattedStartDate {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                Image(systemName: "clock")
                                    .foregroundColor(.blue)
                                    .font(.caption)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    // Show "First occurrence" for recurring events
                                    if event.isRecurring {
                                        Text("First occurrence")
                                            .font(.caption)
                                            .foregroundColor(.blue)
                                            .fontWeight(.medium)
                                    }
                                    
                                    Text(formatRecurringEventTime(start: startDate, end: event.formattedEndDate, isRecurring: event.isRecurring))
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)
                                    
                                    if let timezone = event.timezone {
                                        Text(formatTimezone(timezone))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Spacer()
                                
                                // Duration indicator
                                if let endDate = event.formattedEndDate {
                                    let duration = Calendar.current.dateComponents([.hour, .minute], from: startDate, to: endDate)
                                    let durationText = formatDuration(hours: duration.hour ?? 0, minutes: duration.minute ?? 0)
                                    Text(durationText)
                                        .font(.caption2)
                                        .foregroundColor(.blue)
                                        .fontWeight(.medium)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.blue.opacity(0.1))
                                        .cornerRadius(4)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Color.blue.opacity(0.05))
                        .cornerRadius(10)
                    }
                    
                    // Expandable occurrences for recurring events
                    if event.isRecurring {
                        VStack(alignment: .leading, spacing: 8) {
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showingOccurrences.toggle()
                                }
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: showingOccurrences ? "chevron.down" : "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                    
                                    Text(showingOccurrences ? "Hide occurrences" : "Show next occurrences")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                        .fontWeight(.medium)
                                    
                                    Spacer()
                                    
                                    // Show infinity icon for indefinite recurrences, exact count for finite ones
                                    if isIndefiniteRecurrence(for: event) {
                                        HStack(spacing: 2) {
                                            Image(systemName: "infinity")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                            Text("more")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                    } else {
                                        let totalOccurrences = getOccurrenceCount(for: event)
                                        let remainingOccurrences = totalOccurrences - 1 // Subtract the first occurrence we're showing
                                        Text("\(remainingOccurrences) more")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            if showingOccurrences {
                                LazyVStack(alignment: .leading, spacing: 6) {
                                    ForEach(generateNextOccurrences(for: event).prefix(10), id: \.self) { occurrence in
                                        HStack(spacing: 8) {
                                            Image(systemName: "clock")
                                                .font(.caption2)
                                                .foregroundColor(.blue.opacity(0.7))
                                            
                                            Text(formatOccurrenceDate(occurrence))
                                                .font(.caption)
                                                .foregroundColor(.primary)
                                            
                                            Spacer()
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 4)
                                        .background(Color.blue.opacity(0.03))
                                        .cornerRadius(6)
                                    }
                                    
                                    // Show "more available" indicator for indefinite or if there are more than 10 future occurrences
                                    let futureOccurrences = generateNextOccurrences(for: event)
                                    let showingCount = min(10, futureOccurrences.count)
                                    let remainingAfterShown = futureOccurrences.count - showingCount
                                    
                                    if isIndefiniteRecurrence(for: event) || remainingAfterShown > 0 {
                                        HStack(spacing: 4) {
                                            if isIndefiniteRecurrence(for: event) {
                                                Image(systemName: "infinity")
                                                    .font(.caption2)
                                                    .foregroundColor(.secondary)
                                                Text("continues indefinitely")
                                                    .font(.caption2)
                                                    .foregroundColor(.secondary)
                                                    .italic()
                                            } else {
                                                Image(systemName: "ellipsis")
                                                    .font(.caption2)
                                                    .foregroundColor(.secondary)
                                                Text("and \(remainingAfterShown) more occurrences")
                                                    .font(.caption2)
                                                    .foregroundColor(.secondary)
                                                    .italic()
                                            }
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 2)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                    
                    // Location if available
                    if let location = event.location, !location.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "location")
                                .foregroundColor(.green)
                                .font(.caption)
                            
                            Text(location)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                                .fontWeight(.medium)
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(Color.green.opacity(0.05))
                        .cornerRadius(8)
                    }
                    
                    // Description if available
                    if let description = event.description, !description.isEmpty {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "text.alignleft")
                                .foregroundColor(.purple)
                                .font(.caption)
                            
                            Text(description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(3)
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(Color.purple.opacity(0.05))
                        .cornerRadius(8)
                    }
                }
                
                Spacer(minLength: 0)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)
                    .shadow(
                        color: isSelected ? Color.blue.opacity(0.2) : Color.black.opacity(0.1),
                        radius: isSelected ? 8 : 4,
                        x: 0,
                        y: isSelected ? 4 : 2
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                isSelected ? Color.blue.opacity(0.4) : Color.clear,
                                lineWidth: 2
                            )
                    )
            )
            .scaleEffect(isSelected ? 1.02 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func formatEventTime(start: Date, end: Date?) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .full
        dateFormatter.timeStyle = .none
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateStyle = .none
        timeFormatter.timeStyle = .short
        
        let dateString = dateFormatter.string(from: start)
        let startTimeString = timeFormatter.string(from: start)
        
        if let end = end {
            let endTimeString = timeFormatter.string(from: end)
            return "\(dateString)\n\(startTimeString) - \(endTimeString)"
        } else {
            return "\(dateString)\n\(startTimeString)"
        }
    }
    
    private func formatTimezone(_ timezone: String) -> String {
        if let tz = TimeZone(identifier: timezone) {
            let name = tz.localizedName(for: .standard, locale: .current) ?? timezone.replacingOccurrences(of: "_", with: " ")
            let abbreviation = tz.abbreviation() ?? ""
            return abbreviation.isEmpty ? name : "\(name) (\(abbreviation))"
        }
        return timezone.replacingOccurrences(of: "_", with: " ")
    }
    
    private func formatDuration(hours: Int, minutes: Int) -> String {
        if hours > 0 && minutes > 0 {
            return "\(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else {
            return "1h" // Default duration
        }
    }
    
    private func parseRFC5545Recurrence(_ pattern: String) -> String {
        // Parse RFC 5545 iCalendar recurrence patterns like "FREQ=MONTHLY;INTERVAL=6"
        let components = pattern.components(separatedBy: ";")
        var freq: String?
        var interval = 1 // Default interval is 1
        var byDay: String?
        
        for component in components {
            let trimmed = component.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("freq=") {
                freq = String(trimmed.dropFirst(5))
            } else if trimmed.hasPrefix("interval=") {
                if let intervalValue = Int(String(trimmed.dropFirst(9))) {
                    interval = intervalValue
                }
            } else if trimmed.hasPrefix("byday=") {
                byDay = String(trimmed.dropFirst(6))
            }
        }
        
        guard let frequency = freq else {
            return "Recurs regularly"
        }
        
        return formatRecurrenceDescription(freq: frequency, interval: interval, byDay: byDay)
    }
    
    private func formatRecurrenceDescription(freq: String, interval: Int, byDay: String?) -> String {
        let freqLower = freq.lowercased()
        
        switch freqLower {
        case "daily":
            if interval == 1 {
                return "Recurs daily"
            } else {
                return "Recurs every \(interval) days"
            }
        case "weekly":
            if let byDay = byDay {
                let dayNames = parseDayNames(byDay)
                if interval == 1 {
                    return dayNames.count == 1 ? "Recurs weekly on \(dayNames[0])" : "Recurs weekly on \(dayNames.joined(separator: ", "))"
                } else {
                    return dayNames.count == 1 ? "Recurs every \(interval) weeks on \(dayNames[0])" : "Recurs every \(interval) weeks on \(dayNames.joined(separator: ", "))"
                }
            } else {
                return interval == 1 ? "Recurs weekly" : "Recurs every \(interval) weeks"
            }
        case "monthly":
            if interval == 1 {
                return "Recurs monthly"
            } else {
                return "Recurs every \(interval) months"
            }
        case "yearly":
            if interval == 1 {
                return "Recurs yearly"
            } else {
                return "Recurs every \(interval) years"
            }
        case "hourly":
            if interval == 1 {
                return "Recurs hourly"
            } else {
                return "Recurs every \(interval) hours"
            }
        case "minutely":
            if interval == 1 {
                return "Recurs every minute"
            } else {
                return "Recurs every \(interval) minutes"
            }
        case "secondly":
            if interval == 1 {
                return "Recurs every second"
            } else {
                return "Recurs every \(interval) seconds"
            }
        default:
            return interval == 1 ? "Recurs \(freq)" : "Recurs every \(interval) \(freq.lowercased())"
        }
    }
    
    private func parseDayNames(_ byDay: String) -> [String] {
        // Parse BYDAY values like "MO,WE,FR" or "1MO,-1FR"
        let dayMapping: [String: String] = [
            "mo": "Mon", "tu": "Tue", "we": "Wed", "th": "Thu",
            "fr": "Fri", "sa": "Sat", "su": "Sun"
        ]
        
        let days = byDay.lowercased().components(separatedBy: ",")
        var result: [String] = []
        
        for day in days {
            let trimmed = day.trimmingCharacters(in: .whitespacesAndNewlines)
            // Remove any position indicators (1MO, -1FR, etc.) and just get the day
            let dayCode = String(trimmed.suffix(2))
            if let dayName = dayMapping[dayCode] {
                result.append(dayName)
            }
        }
        
        return result
    }
    
    private func formatComprehensiveRecurrence(_ pattern: String?) -> String {
        guard let pattern = pattern?.lowercased() else { return "Recurs regularly" }
        
        // Parse RFC 5545 iCalendar recurrence rules (FREQ=...; INTERVAL=...)
        if pattern.contains("freq=") {
            return parseRFC5545Recurrence(pattern)
        }
        
        // Handle natural language patterns
        if pattern.contains("daily") || pattern.contains("every day") {
            return "Recurs daily"
        } else if pattern.contains("weekdays") || pattern.contains("monday through friday") {
            return "Recurs weekdays"
        } else if pattern.contains("weekends") {
            return "Recurs weekends"
        } else if pattern.contains("monday") && pattern.contains("wednesday") && pattern.contains("friday") {
            return "Recurs Mon, Wed, Fri"
        } else if pattern.contains("tuesday") && pattern.contains("thursday") {
            return "Recurs Tue, Thu"
        } else if pattern.contains("weekly") {
            if pattern.contains("monday") { return "Recurs weekly on Mon" }
            else if pattern.contains("tuesday") { return "Recurs weekly on Tue" }
            else if pattern.contains("wednesday") { return "Recurs weekly on Wed" }
            else if pattern.contains("thursday") { return "Recurs weekly on Thu" }
            else if pattern.contains("friday") { return "Recurs weekly on Fri" }
            else if pattern.contains("saturday") { return "Recurs weekly on Sat" }
            else if pattern.contains("sunday") { return "Recurs weekly on Sun" }
            else { return "Recurs weekly" }
        } else if pattern.contains("first") && pattern.contains("monday") {
            return "Recurs 1st Mon of month"
        } else if pattern.contains("last") && pattern.contains("friday") {
            return "Recurs last Fri of month"
        } else if pattern.contains("monthly") {
            return "Recurs monthly"
        } else if pattern.contains("yearly") || pattern.contains("annually") {
            return "Recurs yearly"
        } else if pattern.contains("bi-weekly") || pattern.contains("every 2 weeks") {
            return "Recurs bi-weekly"
        } else if pattern.contains("every") && pattern.contains("hour") {
            return "Recurs hourly"
        } else {
            // Check for multiple days pattern
            let days = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"]
            let dayAbbrevs = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
            var foundDays: [String] = []
            
            for (index, day) in days.enumerated() {
                if pattern.contains(day) {
                    foundDays.append(dayAbbrevs[index])
                }
            }
            
            if foundDays.count > 1 {
                if foundDays.count == 2 {
                    return "Recurs \(foundDays[0]) & \(foundDays[1])"
                } else if foundDays.count > 2 {
                    let lastDay = foundDays.removeLast()
                    return "Recurs \(foundDays.joined(separator: ", ")) & \(lastDay)"
                }
            } else if foundDays.count == 1 {
                return "Recurs \(foundDays[0])"
            }
            
            // Fallback to pattern with "Recurs" prefix
            return "Recurs \(pattern.prefix(20).capitalized)"
        }
    }
    
    private func formatRecurringEventTime(start: Date, end: Date?, isRecurring: Bool) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateStyle = .none
        timeFormatter.timeStyle = .short
        
        if isRecurring {
            // For recurring events, show "Starts [date]" and "Ends [date or ∞]"
            let startDateString = dateFormatter.string(from: start)
            let startTimeString = timeFormatter.string(from: start)
            
            if let end = end {
                let endDateString = dateFormatter.string(from: end)
                let endTimeString = timeFormatter.string(from: end)
                
                // Check if it's the same date for single-day recurring events
                if Calendar.current.isDate(start, inSameDayAs: end) {
                    return "Starts \(startDateString)\n\(startTimeString) - \(endTimeString)"
                } else {
                    return "Starts \(startDateString) \(startTimeString)\nEnds \(endDateString) \(endTimeString)"
                }
            } else {
                // No end date - recurring indefinitely
                return "Starts \(startDateString) \(startTimeString)\nEnds ∞ Indefinite"
            }
        } else {
            // Non-recurring events - show the original format
            let dateString = dateFormatter.string(from: start)
            let startTimeString = timeFormatter.string(from: start)
            
            if let end = end {
                let endTimeString = timeFormatter.string(from: end)
                return "\(dateString)\n\(startTimeString) - \(endTimeString)"
            } else {
                return "\(dateString)\n\(startTimeString)"
            }
        }
    }
}

// MARK: - Calendar Picker View
struct CalendarPickerView: View {
    let availableCalendars: [EKCalendar]
    @Binding var selectedCalendar: EKCalendar?
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            List(availableCalendars, id: \.calendarIdentifier) { calendar in
                CalendarRow(
                    calendar: calendar,
                    isSelected: selectedCalendar?.calendarIdentifier == calendar.calendarIdentifier
                ) {
                    selectedCalendar = calendar
                    presentationMode.wrappedValue.dismiss()
                }
            }
            .navigationTitle("Choose Calendar")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                trailing: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }
}

struct CalendarRow: View {
    let calendar: EKCalendar
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Calendar color indicator
                Circle()
                    .fill(Color(calendar.cgColor))
                    .frame(width: 16, height: 16)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(calendar.title)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(calendar.source.title)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(.blue)
                        .font(.body)
                        .fontWeight(.semibold)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())  // Makes entire area tappable
        }
        .buttonStyle(PlainButtonStyle())
        .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
        .cornerRadius(8)
    }
}

// MARK: - Color Extension for Random Colors
extension Color {
    static var random: Color {
        let colors: [Color] = [.red, .blue, .green, .orange, .purple, .pink, .yellow]
        return colors.randomElement() ?? .blue
    }
}

// MARK: - Image Picker
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    let sourceType: UIImagePickerController.SourceType
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let selectedImage = info[.originalImage] as? UIImage {
                parent.image = selectedImage
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

// MARK: - Example Button
struct ExampleButton: View {
    let icon: String
    let text: String
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(.blue)
                    .frame(width: 16)
                
                Text(text)
                    .font(.caption)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.6))
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Full Screen Ad View

// MARK: - Usage Indicator View
struct UsageIndicatorView: View {
    @ObservedObject var subscriptionService: SubscriptionService
    @Binding var showingPremiumModal: Bool
    let dailyConversionsUsed: Int
    let dailyLimit: Int
    let isLoading: Bool
    
    var body: some View {
        let remaining = max(0, dailyLimit - dailyConversionsUsed)
        let isAtLimit = remaining == 0
        
        HStack {
            Text("Daily conversions")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            if isLoading {
                // Loading spinner
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                Text("\(remaining) of \(dailyLimit) remaining")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            
            Spacer()
            
            Button("Upgrade") {
                showingPremiumModal = true
            }
            .font(.caption)
            .foregroundColor(.blue)
            .opacity(isLoading ? 0.6 : 1.0)
            .disabled(isLoading)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.blue.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.blue.opacity(0.1), lineWidth: 1)
                )
        )
    }
}


// MARK: - Banner Ad View
struct BannerAdView: View {
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "crown.fill")
                    .foregroundColor(.yellow)
                    .font(.caption)
                
                Text("Upgrade to Premium")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("Ad-free experience")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Text("Remove ads and get unlimited conversions")
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            LinearGradient(
                colors: [Color.yellow.opacity(0.1), Color.blue.opacity(0.05)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
        )
        .cornerRadius(8)
    }
}

// MARK: - Enhanced Recurring Event Helper Functions

func formatEnhancedRecurrenceBadge(_ event: ParsedEvent) -> String {
    guard let startDate = event.formattedStartDate else { 
        return "Recurs regularly"
    }
    
    // Get base recurrence frequency
    let baseRecurrence = formatRecurrenceFromPattern(event.recurrencePattern)
    
    // Format start date
    let dateFormatter = DateFormatter()
    dateFormatter.dateStyle = .medium
    dateFormatter.timeStyle = .none
    let startDateString = dateFormatter.string(from: startDate)
    
    // Check if there's an end date/pattern (we'll use a heuristic for now)
    let hasEndDate = false // Most recurring events from EventAI are indefinite
    
    if hasEndDate {
        return "\(baseRecurrence), Starts \(startDateString), Ends Dec 31"
    } else {
        // Don't include "Ends indefinite" for indefinite recurrences
        return "\(baseRecurrence), Starts \(startDateString)"
    }
}
    
    func generateNextOccurrences(for event: ParsedEvent) -> [Date] {
        guard let startDate = event.formattedStartDate,
              let pattern = event.recurrencePattern?.uppercased() else {
            return []
        }
        
        var occurrences: [Date] = []
        let calendar = Calendar.current
        var currentDate = startDate
        
        // Parse frequency and interval from pattern
        let frequency = extractFrequency(from: pattern)
        let interval = extractInterval(from: pattern) ?? 1
        
        // Generate up to 50 occurrences (we'll show max 10, but calculate more for counting)
        for _ in 0..<50 {
            switch frequency {
            case "DAILY":
                currentDate = calendar.date(byAdding: .day, value: interval, to: currentDate) ?? currentDate
            case "WEEKLY":
                currentDate = calendar.date(byAdding: .weekOfYear, value: interval, to: currentDate) ?? currentDate
            case "MONTHLY":
                currentDate = calendar.date(byAdding: .month, value: interval, to: currentDate) ?? currentDate
            case "YEARLY":
                currentDate = calendar.date(byAdding: .year, value: interval, to: currentDate) ?? currentDate
            default:
                currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
            }
            
            // Only add future occurrences
            if currentDate > Date() {
                occurrences.append(currentDate)
            }
        }
        
        return occurrences
    }
    
    func getOccurrenceCount(for event: ParsedEvent) -> Int {
        // Calculate exact total occurrences including the first occurrence
        guard let startDate = event.formattedStartDate,
              let pattern = event.recurrencePattern?.uppercased() else { return 1 }
        
        // If pattern has COUNT=, extract that number
        if let countRange = pattern.range(of: "COUNT=") {
            let afterCount = pattern[countRange.upperBound...]
            if let semicolonRange = afterCount.range(of: ";") {
                if let count = Int(String(afterCount[..<semicolonRange.lowerBound])) {
                    return count // This includes the first occurrence
                }
            } else {
                if let count = Int(String(afterCount)) {
                    return count // This includes the first occurrence
                }
            }
        }
        
        // If pattern has UNTIL=, calculate occurrences until that date
        if let untilRange = pattern.range(of: "UNTIL=") {
            let afterUntil = pattern[untilRange.upperBound...]
            let untilString: String
            if let semicolonRange = afterUntil.range(of: ";") {
                untilString = String(afterUntil[..<semicolonRange.lowerBound])
            } else {
                untilString = String(afterUntil)
            }
            
            // Parse until date and calculate occurrences
            if let untilDate = parseSimpleICSDate(untilString) {
                return calculateOccurrencesUntilDate(startDate: startDate, untilDate: untilDate, pattern: pattern)
            }
        }
        
        // For indefinite recurrences, return a reasonable number for display
        // but mark them as indefinite using isIndefiniteRecurrence()
        let frequency = extractFrequency(from: pattern)
        let interval = extractInterval(from: pattern) ?? 1
        
        switch frequency {
        case "DAILY":
            return 1 + (90 / interval) // ~3 months worth
        case "WEEKLY":
            return 1 + (52 / interval) // ~1 year worth  
        case "MONTHLY":
            return 1 + (24 / interval) // ~2 years worth
        case "YEARLY":
            return 1 + (10 / interval) // ~10 years worth
        default:
            return 50 // Default reasonable number
        }
    }
    
    private func calculateOccurrencesUntilDate(startDate: Date, untilDate: Date, pattern: String) -> Int {
        let frequency = extractFrequency(from: pattern)
        let interval = extractInterval(from: pattern) ?? 1
        let calendar = Calendar.current
        var currentDate = startDate
        var count = 1 // Include the first occurrence
        
        while currentDate < untilDate {
            switch frequency {
            case "DAILY":
                currentDate = calendar.date(byAdding: .day, value: interval, to: currentDate) ?? currentDate
            case "WEEKLY":
                currentDate = calendar.date(byAdding: .weekOfYear, value: interval, to: currentDate) ?? currentDate
            case "MONTHLY":
                currentDate = calendar.date(byAdding: .month, value: interval, to: currentDate) ?? currentDate
            case "YEARLY":
                currentDate = calendar.date(byAdding: .year, value: interval, to: currentDate) ?? currentDate
            default:
                currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
            }
            
            if currentDate <= untilDate {
                count += 1
            }
        }
        
        return count
    }
    
    private func parseSimpleICSDate(_ dateString: String) -> Date? {
        let cleanDateString = dateString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Handle UTC dates (ending with Z)
        if cleanDateString.hasSuffix("Z") {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
            formatter.timeZone = TimeZone(identifier: "UTC")
            formatter.locale = Locale(identifier: "en_US_POSIX")
            return formatter.date(from: cleanDateString)
        }
        
        // Handle local time dates: 20241010T140000
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd'T'HHmmss"
        formatter.timeZone = TimeZone.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.date(from: cleanDateString)
    }
    
    func isIndefiniteRecurrence(for event: ParsedEvent) -> Bool {
        // Check if recurrence has no end date/count (indefinite)
        guard let pattern = event.recurrencePattern?.uppercased() else { return false }
        
        // If pattern contains COUNT= or UNTIL=, it's not indefinite
        if pattern.contains("COUNT=") || pattern.contains("UNTIL=") {
            return false
        }
        
        // Most EventAI recurring events are indefinite (no explicit end)
        return true
    }
    
    func formatOccurrenceDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium // Use medium instead of full for shorter text
        formatter.timeStyle = .none   // Remove time to keep text short
        return formatter.string(from: date)
    }
    
    private func extractFrequency(from pattern: String) -> String {
        if let freqRange = pattern.range(of: "FREQ=") {
            let afterFreq = pattern[freqRange.upperBound...]
            if let semicolonRange = afterFreq.range(of: ";") {
                return String(afterFreq[..<semicolonRange.lowerBound])
            } else {
                return String(afterFreq)
            }
        }
        return "DAILY"
    }
    
    private func extractInterval(from pattern: String) -> Int? {
        if let intervalRange = pattern.range(of: "INTERVAL=") {
            let afterInterval = pattern[intervalRange.upperBound...]
            if let semicolonRange = afterInterval.range(of: ";") {
                return Int(String(afterInterval[..<semicolonRange.lowerBound]))
            } else {
                return Int(String(afterInterval))
            }
        }
        return nil
    }

func formatRecurrenceFromPattern(_ pattern: String?) -> String {
    guard let pattern = pattern?.lowercased() else { return "Recurs regularly" }
    
    // Parse RFC 5545 iCalendar recurrence rules (FREQ=...; INTERVAL=...)
    if pattern.contains("freq=") {
        return parseRFC5545RecurrencePattern(pattern)
    }
    
    // Handle natural language patterns
    if pattern.contains("daily") || pattern.contains("every day") {
        return "Recurs daily"
    } else if pattern.contains("weekdays") || pattern.contains("monday through friday") {
        return "Recurs weekdays"
    } else if pattern.contains("weekends") {
        return "Recurs weekends"
    } else if pattern.contains("monday") && pattern.contains("wednesday") && pattern.contains("friday") {
        return "Recurs Mon, Wed, Fri"
    } else if pattern.contains("tuesday") && pattern.contains("thursday") {
        return "Recurs Tue, Thu"
    } else if pattern.contains("weekly") {
        if pattern.contains("monday") { return "Recurs weekly on Mon" }
        else if pattern.contains("tuesday") { return "Recurs weekly on Tue" }
        else if pattern.contains("wednesday") { return "Recurs weekly on Wed" }
        else if pattern.contains("thursday") { return "Recurs weekly on Thu" }
        else if pattern.contains("friday") { return "Recurs weekly on Fri" }
        else if pattern.contains("saturday") { return "Recurs weekly on Sat" }
        else if pattern.contains("sunday") { return "Recurs weekly on Sun" }
        else { return "Recurs weekly" }
    } else if pattern.contains("first") && pattern.contains("monday") {
        return "Recurs 1st Mon of month"
    } else if pattern.contains("last") && pattern.contains("friday") {
        return "Recurs last Fri of month"
    } else if pattern.contains("monthly") {
        return "Recurs monthly"
    } else if pattern.contains("yearly") || pattern.contains("annually") {
        return "Recurs yearly"
    } else if pattern.contains("bi-weekly") || pattern.contains("every 2 weeks") {
        return "Recurs bi-weekly"
    } else if pattern.contains("every") && pattern.contains("hour") {
        return "Recurs hourly"
    } else {
        // Check for multiple days pattern
        let days = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"]
        let dayAbbrevs = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        var foundDays: [String] = []
        
        for (index, day) in days.enumerated() {
            if pattern.contains(day) {
                foundDays.append(dayAbbrevs[index])
            }
        }
        
        if foundDays.count > 1 {
            if foundDays.count == 2 {
                return "Recurs \(foundDays[0]) & \(foundDays[1])"
            } else if foundDays.count > 2 {
                let lastDay = foundDays.removeLast()
                return "Recurs \(foundDays.joined(separator: ", ")) & \(lastDay)"
            }
        } else if foundDays.count == 1 {
            return "Recurs \(foundDays[0])"
        }
        
        // Fallback to pattern with "Recurs" prefix
        return "Recurs \(pattern.prefix(20).capitalized)"
    }
}

func parseRFC5545RecurrencePattern(_ pattern: String) -> String {
    // Parse RFC 5545 iCalendar recurrence patterns like "FREQ=MONTHLY;INTERVAL=6"
    let components = pattern.components(separatedBy: ";")
    var freq: String?
    var interval = 1 // Default interval is 1
    var byDay: String?
    
    for component in components {
        let trimmed = component.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("freq=") {
            freq = String(trimmed.dropFirst(5))
        } else if trimmed.hasPrefix("interval=") {
            if let intervalValue = Int(String(trimmed.dropFirst(9))) {
                interval = intervalValue
            }
        } else if trimmed.hasPrefix("byday=") {
            byDay = String(trimmed.dropFirst(6))
        }
    }
    
    guard let frequency = freq else {
        return "Recurs regularly"
    }
    
    return formatFrequencyDescription(freq: frequency, interval: interval, byDay: byDay)
}

func formatFrequencyDescription(freq: String, interval: Int, byDay: String?) -> String {
    let freqLower = freq.lowercased()
    
    switch freqLower {
    case "daily":
        if interval == 1 {
            return "Recurs daily"
        } else {
            return "Recurs every \(interval) days"
        }
    case "weekly":
        if let byDay = byDay {
            let dayNames = parseDayNamesFromByDay(byDay)
            if interval == 1 {
                return dayNames.count == 1 ? "Recurs weekly on \(dayNames[0])" : "Recurs weekly on \(dayNames.joined(separator: ", "))"
            } else {
                return dayNames.count == 1 ? "Recurs every \(interval) weeks on \(dayNames[0])" : "Recurs every \(interval) weeks on \(dayNames.joined(separator: ", "))"
            }
        } else {
            return interval == 1 ? "Recurs weekly" : "Recurs every \(interval) weeks"
        }
    case "monthly":
        if interval == 1 {
            return "Recurs monthly"
        } else {
            return "Recurs every \(interval) months"
        }
    case "yearly":
        if interval == 1 {
            return "Recurs yearly"
        } else {
            return "Recurs every \(interval) years"
        }
    case "hourly":
        if interval == 1 {
            return "Recurs hourly"
        } else {
            return "Recurs every \(interval) hours"
        }
    case "minutely":
        if interval == 1 {
            return "Recurs every minute"
        } else {
            return "Recurs every \(interval) minutes"
        }
    case "secondly":
        if interval == 1 {
            return "Recurs every second"
        } else {
            return "Recurs every \(interval) seconds"
        }
    default:
        return interval == 1 ? "Recurs \(freq)" : "Recurs every \(interval) \(freq.lowercased())"
    }
}

func parseDayNamesFromByDay(_ byDay: String) -> [String] {
    // Parse BYDAY values like "MO,WE,FR" or "1MO,-1FR"
    let dayMapping: [String: String] = [
        "mo": "Mon", "tu": "Tue", "we": "Wed", "th": "Thu",
        "fr": "Fri", "sa": "Sat", "su": "Sun"
    ]
    
    let days = byDay.lowercased().components(separatedBy: ",")
    var result: [String] = []
    
    for day in days {
        let trimmed = day.trimmingCharacters(in: .whitespacesAndNewlines)
        // Remove any position indicators (1MO, -1FR, etc.) and just get the day
        let dayCode = String(trimmed.suffix(2))
        if let dayName = dayMapping[dayCode] {
            result.append(dayName)
        }
    }
    
    return result
}

#Preview {
    ContentView()
}