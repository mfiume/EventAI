import SwiftUI

struct QuickCreateView: View {
    @EnvironmentObject var apiService: SharedAPIService
    @EnvironmentObject var calendarService: SharedCalendarService
    
    @State private var inputText = ""
    @State private var isProcessing = false
    @State private var showingSuccess = false
    @State private var successMessage = ""
    @State private var errorMessage = ""
    @State private var showingError = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "calendar.badge.plus")
                    .foregroundColor(.blue)
                Text("Quick Create")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Open Main App") {
                    NSApp.activate(ignoringOtherApps: true)
                    NSApp.sendAction(Selector(("showMainWindow:")), to: nil, from: nil)
                }
                .buttonStyle(.borderless)
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            // Quick input
            VStack(alignment: .leading, spacing: 8) {
                Text("Describe your event:")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                TextField("e.g., Team meeting tomorrow at 2pm", text: $inputText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3...5)
                    .onSubmit {
                        if !inputText.isEmpty && !isProcessing {
                            Task {
                                await createEvent()
                            }
                        }
                    }
            }
            
            // Actions
            HStack {
                Button("Create & Add") {
                    Task {
                        await createEvent()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(inputText.isEmpty || isProcessing)
                .controlSize(.small)
                
                Button("Clear") {
                    inputText = ""
                }
                .disabled(inputText.isEmpty)
                .controlSize(.small)
                
                if isProcessing {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 16, height: 16)
                }
            }
            
            // Status
            if showingSuccess {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(successMessage)
                        .font(.caption)
                        .foregroundColor(.green)
                }
            } else if showingError {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .lineLimit(2)
                }
            }
            
            // Tips
            if !showingSuccess && !showingError {
                VStack(alignment: .leading, spacing: 4) {
                    Text("💡 Tips:")
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    Text("• Use natural language: \"Lunch with Sarah Friday 12:30\"")
                    Text("• Include location: \"Meeting at Conference Room A\"")
                    Text("• Add duration: \"2 hour workshop next Monday\"")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(width: 380, height: showingSuccess || showingError ? 240 : 200)
    }
    
    // MARK: - Actions
    private func createEvent() async {
        guard !inputText.isEmpty else { return }
        
        isProcessing = true
        showingSuccess = false
        showingError = false
        
        do {
            let response = try await apiService.convertTextToCalendar(
                text: inputText,
                timezone: TimeZone.current.identifier
            )
            
            if response.success && !response.events.isEmpty {
                // Add events to calendar
                let result = await calendarService.addEventsToCalendar(response.events)
                
                await MainActor.run {
                    if result.success > 0 {
                        successMessage = "✅ Added \(result.success) event\(result.success == 1 ? "" : "s") to calendar!"
                        showingSuccess = true
                        inputText = ""
                        
                        // Auto-hide success message after 3 seconds
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            self.showingSuccess = false
                        }
                    } else {
                        errorMessage = "Failed to add events to calendar"
                        showingError = true
                    }
                    
                    isProcessing = false
                }
            } else {
                await MainActor.run {
                    errorMessage = "No events found in your text"
                    showingError = true
                    isProcessing = false
                }
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showingError = true
                isProcessing = false
            }
        }
    }
}

#Preview {
    QuickCreateView()
        .environmentObject(SharedAPIService.shared)
        .environmentObject(SharedCalendarService.shared)
}