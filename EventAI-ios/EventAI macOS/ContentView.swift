import SwiftUI
import UniformTypeIdentifiers
import EventKit

struct ContentView: View {
    @EnvironmentObject var apiService: SharedAPIService
    @EnvironmentObject var calendarService: SharedCalendarService
    @StateObject private var subscriptionService = RevenueCatService_macOS.shared
    
    @State private var inputText = ""
    @State private var isProcessing = false
    @State private var events: [SharedAPIService.CalendarEvent] = []
    @State private var usageInfo: SharedAPIService.UsageResponse?
    @State private var showingResults = false
    @State private var errorMessage = ""
    @State private var showingError = false
    @State private var selectedTimezone = TimeZone.current.identifier
    @State private var selectedImage: NSImage?
    @State private var showingImagePicker = false
    @State private var selectedCalendar: EKCalendar?
    @State private var showingCalendarPicker = false
    @State private var showingTimezonePicker = false
    @State private var selectedEventIDs: Set<UUID> = []
    @State private var showingPremiumUpgrade = false
    
    private let commonTimezones = [
        "America/New_York",
        "America/Chicago", 
        "America/Denver",
        "America/Los_Angeles",
        "America/Toronto",
        "Europe/London",
        "Europe/Paris",
        "Europe/Berlin",
        "Asia/Tokyo",
        "Asia/Shanghai",
        "Australia/Sydney"
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Top Bar - Usage and Subscription Status
            if let usage = usageInfo {
                HStack(spacing: 12) {
                    // Conversion counter - compact format
                    Text("Daily conversions: \(usage.remaining) of \(usage.limit) remaining")
                        .font(.caption)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    // Status badge - smaller
                    if subscriptionService.isPremium || usage.isPremium {
                        HStack(spacing: 3) {
                            Image(systemName: "crown.fill")
                                .font(.caption2)
                                .foregroundColor(.yellow)
                            Text("Premium")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(.blue)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(4)
                    } else {
                        HStack(spacing: 8) {
                            Text("Free")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(4)
                            
                            Button(action: {
                                showingPremiumUpgrade = true
                            }) {
                                HStack(spacing: 3) {
                                    Image(systemName: "crown.fill")
                                        .font(.caption2)
                                    Text("Upgrade")
                                        .font(.caption2)
                                        .fontWeight(.medium)
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    LinearGradient(
                                        colors: [Color.blue, Color.purple],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(4)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(NSColor.controlBackgroundColor))
                .overlay(
                    Rectangle()
                        .fill(Color(NSColor.separatorColor))
                        .frame(height: 1),
                    alignment: .bottom
                )
            }
            
            // Main Content
            HSplitView {
                // Left Panel - Input
                VStack(alignment: .leading, spacing: 16) {
                
                // Text input area
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Describe your event")
                            .font(.subheadline)
                        
                        Spacer()
                        
                        // Timezone and Photo controls - right aligned
                        HStack(spacing: 12) {
                            Button(selectedTimezone.replacingOccurrences(of: "_", with: " ")) {
                                showingTimezonePicker = true
                            }
                            .buttonStyle(.bordered)
                            
                            if let image = selectedImage {
                                HStack(spacing: 4) {
                                    Image(nsImage: image)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 20, height: 20)
                                        .clipShape(RoundedRectangle(cornerRadius: 2))
                                    
                                    Button("Remove") {
                                        selectedImage = nil
                                    }
                                    .buttonStyle(.borderless)
                                    .foregroundColor(.red)
                                    .font(.caption)
                                }
                            } else {
                                Button("Add Photo") {
                                    showingImagePicker = true
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                    
                    TextEditor(text: $inputText)
                        .font(.body)
                        .padding(8)
                        .background(Color(NSColor.textBackgroundColor))
                        .overlay(
                            Rectangle()
                                .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                        )
                        .onDrop(of: [.text, .fileURL], isTargeted: nil) { providers in
                            handleDrop(providers)
                        }
                    
                    Text("💡 Try: \"Team meeting tomorrow at 2pm\" or drag & drop text files")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Action buttons - bottom aligned
                HStack {
                    Spacer()
                    
                    Button("Create Events") {
                        Task {
                            await processText()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(inputText.isEmpty || isProcessing)
                }
            }
            .padding(8)
            .frame(minWidth: 80)
            
            // Right Panel - Results
            VStack(alignment: .leading, spacing: 16) {
                if isProcessing {
                    // Processing state
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                        
                        Text("Creating events...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if showingResults && !events.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Found \(events.count) event\(events.count == 1 ? "" : "s")")
                            .font(.headline)
                        
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(events) { event in
                                    EventCardWithSelection(event: event, isSelected: Binding(
                                        get: { selectedEventIDs.contains(event.id) },
                                        set: { isSelected in
                                            if isSelected {
                                                selectedEventIDs.insert(event.id)
                                            } else {
                                                selectedEventIDs.remove(event.id)
                                            }
                                        }
                                    ))
                                }
                            }
                            .padding(.vertical, 8)
                        }
                        
                        // Calendar Selection and Add Button
                        VStack(spacing: 12) {
                            // Calendar Selection (only show when access granted)
                            if calendarService.hasCalendarAccess && !calendarService.availableCalendars.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Image(systemName: "folder.badge.plus")
                                            .font(.caption)
                                            .foregroundColor(.green)
                                        
                                        Text("Add to Calendar:")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        
                                        Spacer()
                                    }
                                    
                                    Button(action: { showingCalendarPicker = true }) {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(selectedCalendar?.title ?? calendarService.getDefaultCalendar()?.title ?? "Default Calendar")
                                                    .font(.subheadline)
                                                    .fontWeight(.medium)
                                                    .foregroundColor(.primary)
                                                
                                                if let source = (selectedCalendar ?? calendarService.getDefaultCalendar())?.source {
                                                    Text(source.title)
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                }
                                            }
                                            
                                            Spacer()
                                            
                                            Image(systemName: "chevron.down")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 12)
                                        .background(Color(NSColor.controlBackgroundColor))
                                        .cornerRadius(8)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            
                            // Export buttons
                            HStack(spacing: 12) {
                                Spacer()
                                
                                // Add to Calendar button - no permissions needed
                                Button("Add \(selectedEventIDs.count) Event\(selectedEventIDs.count == 1 ? "" : "s") to Calendar") {
                                    Task {
                                        await exportSelectedEventsAsICS()
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(selectedEventIDs.count == 0)
                                
                                // Direct calendar integration (optional)
                                if calendarService.hasCalendarAccess {
                                    Button("Add Directly") {
                                        Task {
                                            await addSelectedEventsToCalendar()
                                        }
                                    }
                                    .buttonStyle(.bordered)
                                    .disabled(selectedEventIDs.count == 0)
                                }
                            }
                        }
                    }
                } else if showingResults {
                    VStack(spacing: 16) {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.system(size: 48))
                            .foregroundColor(.orange)
                        
                        Text("No events found")
                            .font(.headline)
                        
                        Text("Try being more specific with dates and times")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // Welcome state
                    VStack(spacing: 24) {
                        VStack(spacing: 8) {
                            Text("Enter event details to get started")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("✨ macOS Features:")
                                .font(.headline)
                            
                            Label("Drag & drop text files", systemImage: "doc.text")
                            Label("Menu bar quick access", systemImage: "menubar.rectangle")
                            Label("Keyboard shortcuts", systemImage: "keyboard")
                            Label("Native calendar integration", systemImage: "calendar")
                        }
                        .padding(12)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(12)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .padding(8)
            .frame(minWidth: 80)
            }
        }
        .navigationTitle("Event AI")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button("Quick Create", systemImage: "plus.circle.fill") {
                    // Open quick create window
                }
                
                Button("Settings", systemImage: "gear") {
                    NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
                }
            }
        }
        .onAppear {
            loadUsage()
            // Initialize selected calendar with default
            if selectedCalendar == nil {
                selectedCalendar = calendarService.getDefaultCalendar()
            }
            
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .fileImporter(
            isPresented: $showingImagePicker,
            allowedContentTypes: [.image],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    loadImage(from: url)
                }
            case .failure(let error):
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
        .sheet(isPresented: $showingCalendarPicker) {
            CalendarPickerView(
                availableCalendars: calendarService.availableCalendars,
                selectedCalendar: $selectedCalendar
            )
        }
        .sheet(isPresented: $showingTimezonePicker) {
            MacOSTimezonePickerView(selectedTimezone: $selectedTimezone)
        }
        .sheet(isPresented: $showingPremiumUpgrade) {
            PremiumUpgradeView()
        }
    }
    
    // MARK: - Actions
    private func processText() async {
        guard !inputText.isEmpty else { return }
        
        // Check if user has reached their daily limit (for free users)
        if let usage = usageInfo, 
           !subscriptionService.isPremium && 
           !usage.isPremium && 
           usage.remaining <= 0 {
            await MainActor.run {
                showingPremiumUpgrade = true
            }
            return
        }
        
        isProcessing = true
        showingResults = false
        
        do {
            // Convert NSImage to Data if present
            var imageData: Data?
            if let nsImage = selectedImage {
                imageData = nsImage.tiffRepresentation.flatMap { tiff in
                    NSBitmapImageRep(data: tiff)?.representation(using: .jpeg, properties: [.compressionFactor: 0.8])
                }
            }
            
            let response = try await apiService.convertTextToCalendar(
                text: inputText,
                timezone: selectedTimezone,
                image: imageData
            )
            
            await MainActor.run {
                self.events = response.events
                self.showingResults = true
                self.isProcessing = false
                
                // Select all events by default
                self.selectedEventIDs = Set(response.events.map { $0.id })
                
                // Refresh usage data to get current count
                Task {
                    await refreshUsageData()
                }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.showingError = true
                self.isProcessing = false
            }
        }
    }
    
    private func addSelectedEventsToCalendar() async {
        let selectedEvents = events.filter { selectedEventIDs.contains($0.id) }
        let result = await calendarService.addEventsToCalendar(selectedEvents, selectedCalendar: selectedCalendar)
        
        await MainActor.run {
            if result.success > 0 {
                // Show success message
                let message = "Added \(result.success) event\(result.success == 1 ? "" : "s") to your calendar"
                // You could show a toast or notification here
                print(message)
            }
            
            if result.failed > 0 {
                var errorText = "Failed to add \(result.failed) event\(result.failed == 1 ? "" : "s")"
                if !result.errors.isEmpty {
                    errorText += ": \(result.errors.first ?? "Unknown error")"
                }
                errorMessage = errorText
                showingError = true
            }
        }
    }
    
    private func requestCalendarAccess() async {
        let granted = await calendarService.requestAccess()
        await MainActor.run {
            if !granted {
                errorMessage = "Calendar access was denied. Please allow access in System Settings > Privacy & Security > Calendars."
                showingError = true
            }
        }
    }
    
    private func exportSelectedEventsAsICS() async {
        let selectedEvents = events.filter { selectedEventIDs.contains($0.id) }
        let icsContent = generateICSContent(for: selectedEvents)
        
        await MainActor.run {
            // Create temporary file
            let tempDirectory = FileManager.default.temporaryDirectory
            let icsFileName = "EventAI-Events-\(Int(Date().timeIntervalSince1970)).ics"
            let icsURL = tempDirectory.appendingPathComponent(icsFileName)
            
            do {
                try icsContent.write(to: icsURL, atomically: true, encoding: .utf8)
                
                // Open with default calendar app
                NSWorkspace.shared.open(icsURL)
                
                print("✅ Opened \(selectedEvents.count) events with default calendar app")
            } catch {
                errorMessage = "Failed to create calendar file: \(error.localizedDescription)"
                showingError = true
            }
        }
    }
    
    private func generateICSContent(for events: [SharedAPIService.CalendarEvent]) -> String {
        var icsLines: [String] = []
        
        // ICS Header
        icsLines.append("BEGIN:VCALENDAR")
        icsLines.append("VERSION:2.0")
        icsLines.append("PRODID:-//EventAI//EventAI macOS//EN")
        icsLines.append("CALSCALE:GREGORIAN")
        icsLines.append("METHOD:PUBLISH")
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        
        let localDateFormatter = DateFormatter()
        localDateFormatter.dateFormat = "yyyyMMdd'T'HHmmss"
        
        for event in events {
            guard let startDate = event.formattedStartDate else { continue }
            
            icsLines.append("BEGIN:VEVENT")
            icsLines.append("UID:\(event.id.uuidString)@eventai.app")
            icsLines.append("DTSTAMP:\(dateFormatter.string(from: Date()))")
            
            // Handle all-day events
            if event.isAllDay {
                let allDayFormatter = DateFormatter()
                allDayFormatter.dateFormat = "yyyyMMdd"
                allDayFormatter.timeZone = TimeZone(identifier: selectedTimezone)
                
                icsLines.append("DTSTART;VALUE=DATE:\(allDayFormatter.string(from: startDate))")
                
                if let endDate = event.formattedEndDate {
                    // For all-day events, end date should be the next day
                    let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: endDate) ?? endDate
                    icsLines.append("DTEND;VALUE=DATE:\(allDayFormatter.string(from: nextDay))")
                }
            } else {
                // Regular timed events
                if let timezone = TimeZone(identifier: selectedTimezone) {
                    localDateFormatter.timeZone = timezone
                    icsLines.append("DTSTART;TZID=\(selectedTimezone):\(localDateFormatter.string(from: startDate))")
                    
                    if let endDate = event.formattedEndDate {
                        icsLines.append("DTEND;TZID=\(selectedTimezone):\(localDateFormatter.string(from: endDate))")
                    } else {
                        // Default to 1 hour if no end time
                        let endDate = startDate.addingTimeInterval(3600)
                        icsLines.append("DTEND;TZID=\(selectedTimezone):\(localDateFormatter.string(from: endDate))")
                    }
                }
            }
            
            // Event details
            icsLines.append("SUMMARY:\(escapeICSText(event.title))")
            
            if let notes = event.notes, !notes.isEmpty {
                icsLines.append("DESCRIPTION:\(escapeICSText(notes))")
            }
            
            if let location = event.location, !location.isEmpty {
                icsLines.append("LOCATION:\(escapeICSText(location))")
            }
            
            // Recurrence rules
            if event.isRecurring, let pattern = event.recurrencePattern {
                if let rrule = convertToRRULE(pattern) {
                    icsLines.append("RRULE:\(rrule)")
                }
            }
            
            icsLines.append("END:VEVENT")
        }
        
        icsLines.append("END:VCALENDAR")
        
        return icsLines.joined(separator: "\n")
    }
    
    private func escapeICSText(_ text: String) -> String {
        return text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: ";", with: "\\;")
            .replacingOccurrences(of: ",", with: "\\,")
            .replacingOccurrences(of: "\n", with: "\\n")
    }
    
    private func convertToRRULE(_ pattern: String) -> String? {
        let uppercased = pattern.uppercased()
        
        if uppercased.contains("DAILY") {
            return "FREQ=DAILY"
        } else if uppercased.contains("WEEKLY") {
            return "FREQ=WEEKLY"
        } else if uppercased.contains("MONTHLY") {
            return "FREQ=MONTHLY"
        } else if uppercased.contains("YEARLY") {
            return "FREQ=YEARLY"
        }
        
        return nil
    }
    
    private func loadUsage() {
        Task {
            do {
                let usage = try await apiService.getUsage()
                await MainActor.run {
                    self.usageInfo = usage
                }
            } catch {
                print("❌ Failed to load usage: \(error)")
                // Don't show usage UI if API fails
            }
        }
    }
    
    private func refreshUsageData() async {
        do {
            let usage = try await apiService.getUsage()
            await MainActor.run {
                self.usageInfo = usage
            }
        } catch {
            print("❌ Failed to refresh usage: \(error)")
        }
    }
    
    // MARK: - Drag & Drop
    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            if provider.canLoadObject(ofClass: String.self) {
                provider.loadObject(ofClass: String.self) { text, _ in
                    DispatchQueue.main.async {
                        if let text = text {
                            self.inputText = text
                        }
                    }
                }
                return true
            }
            
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { data, _ in
                    if let data = data as? Data,
                       let url = URL(dataRepresentation: data, relativeTo: nil) {
                        // Read text file
                        do {
                            let content = try String(contentsOf: url, encoding: .utf8)
                            DispatchQueue.main.async {
                                self.inputText = content
                            }
                        } catch {
                            // Handle error
                        }
                    }
                }
                return true
            }
        }
        return false
    }
    
    private func loadImage(from url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            errorMessage = "Unable to access selected file"
            showingError = true
            return
        }
        
        defer {
            url.stopAccessingSecurityScopedResource()
        }
        
        guard let nsImage = NSImage(contentsOf: url) else {
            errorMessage = "Unable to load image from selected file"
            showingError = true
            return
        }
        
        selectedImage = nsImage
    }
}

// MARK: - Event Card View
struct EventCard: View {
    let event: SharedAPIService.CalendarEvent
    @State private var showingOccurrences = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title
            HStack {
                Text(event.title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            // Enhanced recurring badge
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
            
            // Time and date info
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
                                Text(timezone.replacingOccurrences(of: "_", with: " "))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        // Duration indicator
                        if let endDate = event.formattedEndDate {
                            let durationText = isAllDayEvent(start: startDate, end: endDate) ? "All Day" : formatDuration(start: startDate, end: endDate)
                            if !durationText.isEmpty {
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
                            
                            // Show infinity icon for indefinite recurrences
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
                                let remainingOccurrences = totalOccurrences - 1
                                Text("\(remainingOccurrences) more")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    
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
                            
                            // Show "more available" indicator
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
            
            // Location
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
            
            // Description/Notes
            if let notes = event.notes, !notes.isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "text.alignleft")
                        .foregroundColor(.purple)
                        .font(.caption)
                    
                    Text(notes)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .fontWeight(.medium)
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(Color.purple.opacity(0.05))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
    
    // MARK: - Helper Methods
    private func isAllDayEvent(start: Date, end: Date?) -> Bool {
        guard let end = end else { return false }
        
        let calendar = Calendar.current
        let startComponents = calendar.dateComponents([.hour, .minute, .second], from: start)
        let endComponents = calendar.dateComponents([.hour, .minute, .second], from: end)
        
        // Check if start is at midnight (00:00:00)
        let isStartMidnight = startComponents.hour == 0 && startComponents.minute == 0 && startComponents.second == 0
        
        // Check if end is at midnight (00:00:00) and is the next day
        let isEndMidnight = endComponents.hour == 0 && endComponents.minute == 0 && endComponents.second == 0
        let isNextDay = calendar.dateComponents([.day], from: start, to: end).day == 1
        
        return isStartMidnight && isEndMidnight && isNextDay
    }
    
    private func formatRecurringEventTime(start: Date, end: Date?, isRecurring: Bool) -> String {
        // Check if this is an all-day event
        if isAllDayEvent(start: start, end: end) {
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .none
            
            let dateString = dateFormatter.string(from: start)
            
            if isRecurring {
                return "Starts \(dateString)"
            } else {
                return "\(dateString)"
            }
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        
        let startString = dateFormatter.string(from: start)
        
        if isRecurring {
            return "Starts \(startString)"
        } else {
            return startString
        }
    }
    
    private func formatDuration(start: Date, end: Date?) -> String {
        guard let end = end else { return "" }
        
        if isAllDayEvent(start: start, end: end) {
            return "All Day"
        }
        
        let timeInterval = end.timeIntervalSince(start)
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) % 3600 / 60
        
        if hours > 0 && minutes > 0 {
            return "\(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else {
            return ""
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
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
        .frame(minWidth: 300, minHeight: 250)
    }
}

struct CalendarRow: View {
    let calendar: EKCalendar
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        HStack {
            Circle()
                .fill(Color(calendar.cgColor))
                .frame(width: 12, height: 12)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(calendar.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if let source = calendar.source {
                    Text(source.title)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundColor(.blue)
                    .fontWeight(.semibold)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Event Card With Selection
struct EventCardWithSelection: View {
    let event: SharedAPIService.CalendarEvent
    @Binding var isSelected: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Radio button (selection indicator)
            Button(action: {
                isSelected.toggle()
            }) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(isSelected ? .blue : .secondary)
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
            
            // Event card content
            EventCard(event: event)
        }
    }
}

// MARK: - Timezone Picker View
struct MacOSTimezonePickerView: View {
    @Binding var selectedTimezone: String
    @Environment(\.presentationMode) var presentationMode
    @State private var searchText = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with title and cancel button
            HStack {
                Text("Select Timezone")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
                .buttonStyle(.bordered)
            }
            .padding()
            
            Divider()
            
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search timezones...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
            }
            .padding()
            
            // Timezone list
            List(filteredTimezones, id: \.identifier) { timezone in
                MacOSTimezoneRow(
                    timezone: timezone,
                    isSelected: timezone.identifier == selectedTimezone
                ) {
                    selectedTimezone = timezone.identifier
                    presentationMode.wrappedValue.dismiss()
                }
            }
            .listStyle(.plain)
        }
        .frame(minWidth: 500, minHeight: 400)
    }
    
    private var filteredTimezones: [TimeZone] {
        let allTimezones = TimeZone.knownTimeZoneIdentifiers
            .compactMap { TimeZone(identifier: $0) }
            .sorted { timezone1, timezone2 in
                let name1 = (timezone1.localizedName(for: .standard, locale: .current) ?? timezone1.identifier).replacingOccurrences(of: "_", with: " ")
                let name2 = (timezone2.localizedName(for: .standard, locale: .current) ?? timezone2.identifier).replacingOccurrences(of: "_", with: " ")
                return name1 < name2
            }
        
        if searchText.isEmpty {
            return allTimezones
        } else {
            return allTimezones.filter { timezone in
                let name = (timezone.localizedName(for: .standard, locale: .current) ?? timezone.identifier).replacingOccurrences(of: "_", with: " ")
                let identifier = timezone.identifier.replacingOccurrences(of: "_", with: " ")
                return name.localizedCaseInsensitiveContains(searchText) || 
                       identifier.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
}

struct MacOSTimezoneRow: View {
    let timezone: TimeZone
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(cleanTimezoneName)
                    .font(.body)
                Text(cleanIdentifier)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(gmtOffsetString)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(4)
                .padding(.trailing, 8)
            
            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundColor(.blue)
                    .fontWeight(.semibold)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .padding(.vertical, 4)
    }
    
    private var cleanTimezoneName: String {
        let name = timezone.localizedName(for: .standard, locale: .current) ?? timezone.identifier
        return name.replacingOccurrences(of: "_", with: " ")
    }
    
    private var cleanIdentifier: String {
        return timezone.identifier.replacingOccurrences(of: "_", with: " ")
    }
    
    private var gmtOffsetString: String {
        let offset = timezone.secondsFromGMT()
        let hours = offset / 3600
        let minutes = abs(offset % 3600) / 60
        
        if hours == 0 && minutes == 0 {
            return "GMT"
        } else if minutes == 0 {
            return String(format: "GMT%+d", hours)
        } else {
            let sign = hours >= 0 ? "+" : "-"
            return String(format: "GMT%@%d:%02d", sign, abs(hours), minutes)
        }
    }
}

// MARK: - Extensions
// MARK: - Recurring Events Helper Functions
private func formatEnhancedRecurrenceBadge(_ event: SharedAPIService.CalendarEvent) -> String {
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
    
    // Most recurring events from EventAI are indefinite
    return "\(baseRecurrence), Starts \(startDateString)"
}

private func generateNextOccurrences(for event: SharedAPIService.CalendarEvent) -> [Date] {
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
            break
        }
        
        // Don't add dates more than 2 years in the future for display purposes
        if currentDate.timeIntervalSince(Date()) > 2 * 365 * 24 * 3600 {
            break
        }
        
        occurrences.append(currentDate)
    }
    
    return occurrences
}

private func isIndefiniteRecurrence(for event: SharedAPIService.CalendarEvent) -> Bool {
    // Check if recurrence has no end date/count (indefinite)
    guard let pattern = event.recurrencePattern?.uppercased() else { return false }
    
    // If pattern contains COUNT= or UNTIL=, it's not indefinite
    if pattern.contains("COUNT=") || pattern.contains("UNTIL=") {
        return false
    }
    
    // Most EventAI recurring events are indefinite (no explicit end)
    return true
}

private func formatOccurrenceDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .none
    return formatter.string(from: date)
}

private func getOccurrenceCount(for event: SharedAPIService.CalendarEvent) -> Int {
    guard let pattern = event.recurrencePattern?.uppercased() else { return 1 }
    
    // Extract COUNT from pattern like "FREQ=WEEKLY;COUNT=10"
    if let countRange = pattern.range(of: "COUNT=") {
        let afterCount = pattern[countRange.upperBound...]
        if let semicolonRange = afterCount.range(of: ";") {
            let countString = String(afterCount[..<semicolonRange.lowerBound])
            return Int(countString) ?? 1
        } else {
            // COUNT is the last parameter
            let countString = String(afterCount)
            return Int(countString) ?? 1
        }
    }
    
    // For indefinite recurrences, return a reasonable number for display
    return 50
}

private func extractFrequency(from pattern: String) -> String {
    if let range = pattern.range(of: "FREQ=") {
        let afterFreq = pattern[range.upperBound...]
        if let semicolonRange = afterFreq.range(of: ";") {
            return String(afterFreq[..<semicolonRange.lowerBound])
        } else {
            return String(afterFreq)
        }
    }
    return "DAILY" // Default fallback
}

private func extractInterval(from pattern: String) -> Int? {
    if let range = pattern.range(of: "INTERVAL=") {
        let afterInterval = pattern[range.upperBound...]
        if let semicolonRange = afterInterval.range(of: ";") {
            return Int(String(afterInterval[..<semicolonRange.lowerBound]))
        } else {
            return Int(String(afterInterval))
        }
    }
    return nil
}

private func formatRecurrenceFromPattern(_ pattern: String?) -> String {
    guard let pattern = pattern?.uppercased() else { return "Regularly" }
    
    let frequency = extractFrequency(from: pattern)
    let interval = extractInterval(from: pattern) ?? 1
    
    switch frequency {
    case "DAILY":
        return interval == 1 ? "Daily" : "Every \(interval) days"
    case "WEEKLY":
        return interval == 1 ? "Weekly" : "Every \(interval) weeks"
    case "MONTHLY":
        return interval == 1 ? "Monthly" : "Every \(interval) months"
    case "YEARLY":
        return interval == 1 ? "Yearly" : "Every \(interval) years"
    default:
        return "Regularly"
    }
}

extension DateFormatter {
    static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter
    }()
    
    static let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}