import SwiftUI
import EventKit
import UIKit
import PhotosUI

// MARK: - ContentView
struct ContentView: View {
    @State private var inputText = ""
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var selectedTimezone = TimeZone.current
    @State private var showEventPreview = false
    @State private var currentEvents: [CalendarEvent] = []
    @State private var selectedImage: UIImage?
    @State private var showingImagePicker = false
    @State private var showingSettings = false
    @State private var showAPIKeyAlert = false
    @FocusState private var isTextFieldFocused: Bool
    @StateObject private var calendarService = CalendarService()
    @StateObject private var locationService = LocationService()

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                inputSection

                Spacer()
            }
            .padding()
            .navigationTitle("Event AI")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gear")
                    }
                }
            }
            .onTapGesture {
                isTextFieldFocused = false
            }
            .alert("EventAI", isPresented: $showAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
            .alert("API Key Required", isPresented: $showAPIKeyAlert) {
                Button("Open Settings") {
                    showingSettings = true
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Please configure your AI API key in Settings to use EventAI.")
            }
            .sheet(isPresented: $showEventPreview) {
                EventPreviewView(
                    events: currentEvents,
                    calendarService: calendarService,
                    userTimezone: selectedTimezone,
                    onEventsAdded: { addedCount in
                        clearAll()
                        showEventPreview = false
                    }
                )
            }
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(image: $selectedImage, sourceType: .photoLibrary)
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
        }
    }

    // MARK: - Input Section
    private var inputSection: some View {
        VStack(spacing: 16) {
            // Text input
            ZStack(alignment: .topLeading) {
                if inputText.isEmpty {
                    Text("Enter event details like:\n\"Team meeting tomorrow at 2pm\"\nor\n\"Weekly standup every Monday at 10am\"")
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 8)
                }

                TextEditor(text: $inputText)
                    .focused($isTextFieldFocused)
                    .frame(minHeight: 120)
                    .padding(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
            }

            // Image picker section
            HStack {
                if let image = selectedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            Button(action: { selectedImage = nil }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.white)
                                    .background(Circle().fill(Color.black.opacity(0.6)))
                            }
                            .offset(x: 25, y: -25),
                            alignment: .topTrailing
                        )
                }

                Button(action: { showingImagePicker = true }) {
                    HStack {
                        Image(systemName: "photo")
                        Text(selectedImage == nil ? "Add Image" : "Change Image")
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(8)
                }

                Spacer()
            }

            // Convert button
            Button(action: { Task { await convertToEvents() } }) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "calendar.badge.plus")
                    }
                    Text(isLoading ? "Processing..." : "Create Calendar Events")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(inputText.isEmpty || isLoading ? Color.gray : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(inputText.isEmpty || isLoading)
        }
    }

    // MARK: - Convert to Events
    private func convertToEvents() async {
        // Check if API key is configured
        guard let apiKey = try? KeychainService.loadAPIKey(), !apiKey.isEmpty else {
            showAPIKeyAlert = true
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            // Load AI configuration
            let configuration = AIConfiguration.load()

            // Create AI service
            let aiService = AIServiceFactory.createService(configuration: configuration, apiKey: apiKey)

            // Get timezone
            let timezone = selectedTimezone.identifier

            // Convert text to events
            let events = try await aiService.convertTextToEvents(
                text: inputText,
                timezone: timezone,
                image: selectedImage
            )

            // Store events directly
            currentEvents = events

            if currentEvents.isEmpty {
                alertMessage = "No events found in the text. Please try rephrasing your input."
                showAlert = true
            } else {
                showEventPreview = true
            }

        } catch AIServiceError.invalidAPIKey {
            alertMessage = "Invalid API key. Please check your settings and try again."
            showAlert = true
        } catch AIServiceError.rateLimitExceeded {
            alertMessage = "Rate limit exceeded. Please wait a moment and try again."
            showAlert = true
        } catch {
            alertMessage = "Error: \(error.localizedDescription)"
            showAlert = true
        }
    }

    // MARK: - Clear All
    private func clearAll() {
        inputText = ""
        selectedImage = nil
        currentEvents = []
    }
}

// MARK: - Event Preview View
struct EventPreviewView: View {
    let events: [CalendarEvent]
    let calendarService: CalendarService
    let userTimezone: TimeZone
    let onEventsAdded: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedEvents: Set<UUID> = []
    @State private var isAddingToCalendar = false
    @State private var selectedCalendar: EKCalendar?

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Calendar Picker Section
                if !calendarService.availableCalendars.isEmpty {
                    VStack(spacing: 0) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Add to Calendar")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .textCase(.uppercase)

                                if let selectedCal = selectedCalendar {
                                    HStack(spacing: 8) {
                                        Circle()
                                            .fill(Color(cgColor: selectedCal.cgColor))
                                            .frame(width: 10, height: 10)
                                        Text(selectedCal.title)
                                            .font(.body)
                                            .fontWeight(.medium)
                                    }
                                }
                            }

                            Spacer()

                            Menu {
                                ForEach(calendarService.availableCalendars, id: \.calendarIdentifier) { calendar in
                                    Button(action: {
                                        selectedCalendar = calendar
                                    }) {
                                        HStack {
                                            Circle()
                                                .fill(Color(cgColor: calendar.cgColor))
                                                .frame(width: 10, height: 10)
                                            Text(calendar.title)
                                            if calendar.calendarIdentifier == selectedCalendar?.calendarIdentifier {
                                                Spacer()
                                                Image(systemName: "checkmark")
                                                    .foregroundColor(.blue)
                                            }
                                        }
                                    }
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Text("Change")
                                        .font(.subheadline)
                                    Image(systemName: "chevron.down")
                                        .font(.caption)
                                }
                                .foregroundColor(.blue)
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                    }

                    Divider()
                }

                if events.isEmpty {
                    Spacer()
                    Text("No events to display")
                        .foregroundColor(.secondary)
                    Spacer()
                } else {
                    List(events) { event in
                        EventRow(event: event, isSelected: selectedEvents.contains(event.id))
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if selectedEvents.contains(event.id) {
                                    selectedEvents.remove(event.id)
                                } else {
                                    selectedEvents.insert(event.id)
                                }
                            }
                    }
                    .listStyle(.plain)
                }

                if !events.isEmpty {
                    Button(action: addToCalendar) {
                        HStack {
                            if isAddingToCalendar {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Image(systemName: "calendar.badge.plus")
                            }
                            Text("Add \(selectedEvents.count) Event\(selectedEvents.count == 1 ? "" : "s") to Calendar")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(selectedEvents.isEmpty || isAddingToCalendar ? Color.gray : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(selectedEvents.isEmpty || isAddingToCalendar)
                    .padding()
                }
            }
            .navigationTitle("Preview Events")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(selectedEvents.count == events.count ? "Deselect All" : "Select All") {
                        if selectedEvents.count == events.count {
                            selectedEvents.removeAll()
                        } else {
                            selectedEvents = Set(events.map { $0.id })
                        }
                    }
                }
            }
            .onAppear {
                // Select all events by default
                selectedEvents = Set(events.map { $0.id })

                // Set default calendar
                if selectedCalendar == nil {
                    selectedCalendar = calendarService.getDefaultCalendar()
                }

                // Request calendar access if needed
                if !calendarService.hasCalendarAccess {
                    calendarService.requestCalendarAccess()
                }
            }
        }
    }

    private func addToCalendar() {
        guard let calendar = selectedCalendar else {
            print("❌ No calendar selected")
            return
        }

        isAddingToCalendar = true

        Task {
            let eventsToAdd = events.filter { selectedEvents.contains($0.id) }
            var addedCount = 0

            for event in eventsToAdd {
                do {
                    try await calendarService.addEventToCalendar(event: event, timezone: userTimezone, selectedCalendar: calendar)
                    addedCount += 1
                    print("✅ Added event: \(event.title) to calendar: \(calendar.title)")
                } catch {
                    print("❌ Failed to add event: \(error)")
                }
            }

            await MainActor.run {
                isAddingToCalendar = false
                onEventsAdded(addedCount)
            }
        }
    }
}

// MARK: - Event Row
struct EventRow: View {
    let event: CalendarEvent
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isSelected ? .blue : .gray)
                .font(.title3)

            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.headline)

                if let startDate = event.formattedStartDate {
                    Text(formatDate(startDate))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                if let location = event.location {
                    Label(location, systemImage: "location")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if event.isRecurring, let pattern = event.recurrencePattern {
                    Label(pattern, systemImage: "repeat")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Image Picker
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    let sourceType: UIImagePickerController.SourceType

    @Environment(\.dismiss) private var dismiss

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

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let uiImage = info[.originalImage] as? UIImage {
                parent.image = uiImage
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
