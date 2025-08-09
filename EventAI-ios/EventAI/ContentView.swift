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
    @State private var useLocationForTimezone = false
    @State private var showEventPreview = false
    @State private var currentEvents: [ParsedEvent] = []
    @State private var currentICSContent = ""
    @State private var selectedImage: UIImage?
    @State private var showingImagePicker = false
    @State private var imageSourceType: UIImagePickerController.SourceType = .photoLibrary
    @FocusState private var isTextFieldFocused: Bool
    @StateObject private var apiService = APIService()
    @StateObject private var calendarService = CalendarService()
    @StateObject private var adService = AdService()
    @StateObject private var locationService = LocationService()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                inputSection
                
                Spacer()
                
                if showAdBanner && adService.isAdLoaded {
                    adService.loadBannerAd()
                        .frame(height: 60)
                        .cornerRadius(8)
                }
            }
            .padding()
            .navigationTitle("EventAI")
            .navigationBarTitleDisplayMode(.inline)
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
        }
        .onAppear {
            calendarService.requestCalendarAccess()
            adService.initializeAds()
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
                        
                        // Location services toggle button
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
                                        .foregroundColor(hasContent ? .blue : .gray.opacity(0.5))
                                }
                            }
                            .frame(width: 24, height: 24)
                            .background(isLoading ? Color.blue : Color.clear)
                            .clipShape(Circle())
                        }
                        .disabled(!hasContent || isLoading)
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
                    Text("Transform text and images into calendar events...")
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
                        
                        ExampleButton(
                            icon: "location",
                            text: "Lunch with Sarah next Friday at Italian restaurant",
                            onTap: { inputText = "Lunch with Sarah next Friday at Italian restaurant" }
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
    
    private func generateCalendarEvents() {
        guard hasContent else { return }
        
        // Remove focus and dismiss keyboard when generating events
        isTextFieldFocused = false
        
        isLoading = true
        
        Task {
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
                    } else {
                        alertMessage = response.message
                        showAlert = true
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

// MARK: - Timezone Picker View
struct TimezonePickerView: View {
    @Binding var selectedTimezone: TimeZone
    @Environment(\.presentationMode) var presentationMode
    @State private var searchText = ""
    
    var body: some View {
        VStack {
            SearchBar(text: $searchText)
            
            List(filteredTimezones, id: \.identifier) { timezone in
                TimezoneRow(
                    timezone: timezone,
                    isSelected: timezone.identifier == selectedTimezone.identifier
                ) {
                    selectedTimezone = timezone
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
        .navigationTitle("Select Timezone")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var filteredTimezones: [TimeZone] {
        let allTimezones = TimeZone.knownTimeZoneIdentifiers
            .compactMap { TimeZone(identifier: $0) }
            .sorted { timezone1, timezone2 in
                let name1 = timezone1.localizedName(for: .standard, locale: .current) ?? timezone1.identifier
                let name2 = timezone2.localizedName(for: .standard, locale: .current) ?? timezone2.identifier
                return name1 < name2
            }
        
        if searchText.isEmpty {
            return allTimezones
        } else {
            return allTimezones.filter { timezone in
                let name = timezone.localizedName(for: .standard, locale: .current) ?? timezone.identifier
                let identifier = timezone.identifier
                return name.localizedCaseInsensitiveContains(searchText) || 
                       identifier.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
}

struct TimezoneRow: View {
    let timezone: TimeZone
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(timezone.localizedName(for: .standard, locale: .current) ?? timezone.identifier)
                    .font(.body)
                Text(timezone.identifier)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundColor(.blue)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
}

struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search timezones...", text: $text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            if !text.isEmpty {
                Button("Clear") {
                    text = ""
                }
                .foregroundColor(.blue)
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Location Service
@MainActor
class LocationService: NSObject, ObservableObject {
    @Published var isLocationEnabled: Bool = false
    @Published var currentLocation: CLLocation?
    @Published var locationString: String?
    @Published var inferredTimezone: TimeZone?
    
    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        
        // Check current authorization status
        updateLocationStatus()
    }
    
    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    func getCurrentLocation() {
        guard locationManager.authorizationStatus == .authorizedWhenInUse ||
              locationManager.authorizationStatus == .authorizedAlways else {
            requestLocationPermission()
            return
        }
        
        locationManager.requestLocation()
    }
    
    private func updateLocationStatus() {
        let status = locationManager.authorizationStatus
        isLocationEnabled = status == .authorizedWhenInUse || status == .authorizedAlways
        
        if isLocationEnabled {
            getCurrentLocation()
        }
    }
    
    private func reverseGeocode(_ location: CLLocation) {
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            guard let self = self,
                  let placemark = placemarks?.first,
                  error == nil else {
                print("Geocoding error: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            Task { @MainActor in
                // Create location string from placemark
                var locationComponents: [String] = []
                
                if let locality = placemark.locality {
                    locationComponents.append(locality)
                }
                if let administrativeArea = placemark.administrativeArea {
                    locationComponents.append(administrativeArea)
                }
                if let country = placemark.country {
                    locationComponents.append(country)
                }
                
                self.locationString = locationComponents.joined(separator: ", ")
                
                // Infer timezone from the location
                self.inferredTimezone = placemark.timeZone
                
                print("📍 Location: \(self.locationString ?? "Unknown")")
                print("⏰ Inferred timezone: \(self.inferredTimezone?.identifier ?? "Unknown")")
            }
        }
    }
}

extension LocationService: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        currentLocation = location
        reverseGeocode(location)
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        updateLocationStatus()
    }
}

// MARK: - Event Preview View
struct EventPreviewView: View {
    let events: [ParsedEvent]
    let icsContent: String
    let calendarService: CalendarService
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
    
    init(events: [ParsedEvent], icsContent: String, calendarService: CalendarService, onEventsAdded: @escaping (Int) -> Void) {
        self.events = events
        self.icsContent = icsContent
        self.calendarService = calendarService
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
                        
                        ForEach(events) { event in
                            EventCard(
                                event: event,
                                isSelected: selectedEvents.contains(event.id)
                            ) {
                                toggleEventSelection(event.id)
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
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Main celebration icon
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 100))
                    .foregroundColor(.green)
                    .scaleEffect(celebrationScale)
                    .rotationEffect(.degrees(celebrationRotation))
                
                // Success message
                VStack(spacing: 8) {
                    Text("🎉 Success!")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("Added \(selectedEvents.count) event\(selectedEvents.count == 1 ? "" : "s") to your calendar")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                }
                .opacity(celebrationOpacity)
                
                // Confetti effect
                ForEach(0..<12, id: \.self) { i in
                    Circle()
                        .fill(Color.random)
                        .frame(width: 8, height: 8)
                        .offset(
                            x: CGFloat.random(in: -100...100),
                            y: CGFloat.random(in: -200...0)
                        )
                        .opacity(celebrationOpacity)
                        .animation(
                            .easeOut(duration: 2.0).delay(Double.random(in: 0...0.5)),
                            value: confettiTrigger
                        )
                }
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
        
        calendarService.addEventsToCalendar(icsContent: icsContent, selectedCalendar: selectedCalendar) { success, error in
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
        
        // Animate the checkmark
        withAnimation(.spring(response: 0.6, dampingFraction: 0.3)) {
            celebrationScale = 1.2
        }
        
        withAnimation(.easeInOut(duration: 1.0)) {
            celebrationRotation = 360
            celebrationOpacity = 1.0
        }
        
        // Auto-dismiss after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.easeOut(duration: 0.5)) {
                celebrationOpacity = 0
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
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
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Selection indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(isSelected ? .blue : .gray)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
                
                VStack(alignment: .leading, spacing: 12) {
                    // Header: Title only (removed recurring badge from here)
                    HStack {
                        Text(event.title)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Spacer()
                    }
                    
                    // Time and timezone info - REQUIRED for ICS
                    if let startDate = event.formattedStartDate {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                Image(systemName: "clock")
                                    .foregroundColor(.blue)
                                    .font(.caption)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(formatEventTime(start: startDate, end: event.formattedEndDate))
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
                            
                            // Recurring badge - moved here, under the date/time section
                            if event.isRecurring {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.caption2)
                                        .foregroundColor(.orange)
                                    Text("Recurs \(formatRecurrenceFrequency(event.recurrencePattern))")
                                        .font(.caption2)
                                        .foregroundColor(.orange)
                                        .fontWeight(.medium)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.orange.opacity(0.15))
                                .cornerRadius(6)
                            }
                            
                            // Recurrence details if applicable
                            if event.isRecurring, let pattern = event.recurrencePattern {
                                HStack(spacing: 4) {
                                    Image(systemName: "repeat")
                                        .font(.caption2)
                                        .foregroundColor(.orange)
                                    Text("Repeats: \(pattern)")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                        .fontWeight(.medium)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Color.blue.opacity(0.05))
                        .cornerRadius(10)
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
    
    private func formatRecurrenceFrequency(_ pattern: String?) -> String {
        guard let pattern = pattern?.lowercased() else { return "regularly" }
        
        if pattern.contains("daily") || pattern.contains("every day") {
            return "daily"
        } else if pattern.contains("weekdays") || pattern.contains("monday through friday") {
            return "weekdays"
        } else if pattern.contains("weekends") {
            return "weekends"
        } else if pattern.contains("monday") && pattern.contains("wednesday") && pattern.contains("friday") {
            return "Mon, Wed, Fri"
        } else if pattern.contains("tuesday") && pattern.contains("thursday") {
            return "Tue, Thu"
        } else if pattern.contains("weekly") {
            if pattern.contains("monday") { return "weekly on Monday" }
            else if pattern.contains("tuesday") { return "weekly on Tuesday" }
            else if pattern.contains("wednesday") { return "weekly on Wednesday" }
            else if pattern.contains("thursday") { return "weekly on Thursday" }
            else if pattern.contains("friday") { return "weekly on Friday" }
            else if pattern.contains("saturday") { return "weekly on Saturday" }
            else if pattern.contains("sunday") { return "weekly on Sunday" }
            else { return "weekly" }
        } else if pattern.contains("first") && pattern.contains("monday") {
            return "first Monday of month"
        } else if pattern.contains("last") && pattern.contains("friday") {
            return "last Friday of month"
        } else if pattern.contains("monthly") {
            return "monthly"
        } else if pattern.contains("yearly") || pattern.contains("annually") {
            return "yearly"
        } else if pattern.contains("bi-weekly") || pattern.contains("every 2 weeks") {
            return "bi-weekly"
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
                    return "\(foundDays[0]) & \(foundDays[1])"
                } else if foundDays.count > 2 {
                    let lastDay = foundDays.removeLast()
                    return "\(foundDays.joined(separator: ", ")) & \(lastDay)"
                }
            }
            
            return pattern.capitalized
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
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
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

#Preview {
    ContentView()
}