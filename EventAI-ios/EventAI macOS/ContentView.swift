import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject var apiService: SharedAPIService
    @EnvironmentObject var calendarService: SharedCalendarService
    
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
        HSplitView {
            // Left Panel - Input
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "calendar.badge.plus")
                            .font(.title2)
                            .foregroundColor(.blue)
                        Text("EventAI")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        // Usage indicator
                        if let usage = usageInfo {
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("\(usage.remaining) of \(usage.limit) remaining")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                if usage.isPremium {
                                    Text("Premium")
                                        .font(.caption2)
                                        .foregroundColor(.blue)
                                } else {
                                    Text("Free")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    
                    Text("Create calendar events from text, emails, and photos.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // Text input area
                VStack(alignment: .leading, spacing: 12) {
                    Text("Describe your event:")
                        .font(.headline)
                    
                    TextEditor(text: $inputText)
                        .font(.body)
                        .frame(minHeight: 120)
                        .padding(8)
                        .background(Color(NSColor.textBackgroundColor))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                        )
                        .onDrop(of: [.text, .fileURL], isTargeted: nil) { providers in
                            handleDrop(providers)
                        }
                    
                    Text("💡 Try: \"Team meeting tomorrow at 2pm\" or drag & drop text files")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Timezone and Photo controls
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Timezone:")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Picker("Timezone", selection: $selectedTimezone) {
                            ForEach(commonTimezones, id: \.self) { timezone in
                                Text(timezone.replacingOccurrences(of: "_", with: " "))
                                    .tag(timezone)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: 200)
                        
                        Spacer()
                    }
                    
                    HStack {
                        Text("Photo (optional):")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        if let image = selectedImage {
                            Image(nsImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 40, height: 40)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                            
                            Button("Remove") {
                                selectedImage = nil
                            }
                            .buttonStyle(.borderless)
                            .foregroundColor(.red)
                        } else {
                            Button("Add Photo") {
                                showingImagePicker = true
                            }
                            .buttonStyle(.bordered)
                        }
                        
                        Spacer()
                    }
                }
                
                // Action buttons
                HStack {
                    Button("Create Events") {
                        Task {
                            await processText()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(inputText.isEmpty || isProcessing)
                    
                    if isProcessing {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
                
                Spacer()
            }
            .padding()
            .frame(minWidth: 350, maxWidth: 400)
            
            // Right Panel - Results
            VStack(alignment: .leading, spacing: 16) {
                if showingResults && !events.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Found \(events.count) event\(events.count == 1 ? "" : "s")")
                            .font(.headline)
                        
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(events) { event in
                                    EventCard(event: event)
                                }
                            }
                            .padding(.vertical, 8)
                        }
                        
                        // Add to Calendar button
                        HStack {
                            Button("Add All to Calendar") {
                                Task {
                                    await addEventsToCalendar()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(events.isEmpty)
                            
                            if !calendarService.hasCalendarAccess && calendarService.canRequestAccess {
                                Button("Request Calendar Access") {
                                    Task {
                                        await requestCalendarAccess()
                                    }
                                }
                                .buttonStyle(.bordered)
                            }
                            
                            Spacer()
                            
                            Text("Calendar access: \(calendarService.hasCalendarAccess ? "✅" : "❌")")
                                .font(.caption)
                                .foregroundColor(.secondary)
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
                        Image(systemName: "calendar.badge.plus")
                            .font(.system(size: 64))
                            .foregroundColor(.blue)
                        
                        VStack(spacing: 8) {
                            Text("Welcome to EventAI")
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            Text("Enter event details to get started")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("✨ macOS Features:")
                                .font(.headline)
                            
                            Label("Drag & drop text files", systemImage: "doc.text")
                            Label("Menu bar quick access", systemImage: "menubar.rectangle")
                            Label("Keyboard shortcuts", systemImage: "keyboard")
                            Label("Native calendar integration", systemImage: "calendar")
                        }
                        .padding()
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(12)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .padding()
            .frame(minWidth: 400)
        }
        .navigationTitle("EventAI")
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
    }
    
    // MARK: - Actions
    private func processText() async {
        guard !inputText.isEmpty else { return }
        
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
                
                // Update usage info if available
                if let usage = response.usageInfo {
                    self.usageInfo = SharedAPIService.UsageResponse(
                        allowed: usage.remaining > 0,
                        count: usage.count,
                        limit: usage.limit,
                        remaining: usage.remaining,
                        isPremium: false,
                        resetDate: usage.resetDate,
                        resetTime: nil,
                        resetTimezone: nil
                    )
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
    
    private func addEventsToCalendar() async {
        let result = await calendarService.addEventsToCalendar(events)
        
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
    
    private func loadUsage() {
        Task {
            do {
                let usage = try await apiService.getUsage()
                await MainActor.run {
                    self.usageInfo = usage
                }
            } catch {
                // Handle silently for now
            }
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(event.title)
                .font(.headline)
            
            if let startDate = event.formattedStartDate {
                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(.blue)
                    
                    if event.isAllDay {
                        Text(DateFormatter.dayFormatter.string(from: startDate))
                    } else {
                        Text(DateFormatter.dateTimeFormatter.string(from: startDate))
                    }
                    
                    if event.isRecurring {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.orange)
                    }
                }
                .font(.subheadline)
            }
            
            if let location = event.location, !location.isEmpty {
                HStack {
                    Image(systemName: "location")
                        .foregroundColor(.green)
                    Text(location)
                }
                .font(.subheadline)
            }
            
            if let notes = event.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

// MARK: - Extensions
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