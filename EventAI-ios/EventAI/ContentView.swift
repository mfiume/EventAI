import SwiftUI
import EventKit

struct ContentView: View {
    @State private var inputText = ""
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var showAdBanner = true
    @StateObject private var apiService = APIService()
    @StateObject private var calendarService = CalendarService()
    @StateObject private var adService = AdService()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                headerView
                
                inputSection
                
                generateButton
                
                Spacer()
                
                if showAdBanner && adService.isAdLoaded {
                    adService.loadBannerAd()
                        .frame(height: 60)
                        .cornerRadius(8)
                }
            }
            .padding()
            .navigationTitle("EventAI")
            .alert("EventAI", isPresented: $showAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
        }
        .onAppear {
            calendarService.requestCalendarAccess()
            adService.initializeAds()
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 8) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 48))
                .foregroundColor(.blue)
            
            Text("Transform text into calendar events")
                .font(.title3)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        }
        .padding(.top)
    }
    
    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Enter your text:")
                .font(.headline)
            
            TextEditor(text: $inputText)
                .frame(minHeight: 120)
                .padding(8)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
            
            Text("Example: \"Dentist appointment tomorrow at 2pm\" or \"Team meeting next Monday from 9 to 10 AM\"")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var generateButton: some View {
        Button(action: generateCalendarEvents) {
            HStack {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .foregroundColor(.white)
                }
                
                Text(isLoading ? "Generating..." : "Generate Calendar Events")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading ? Color.gray : Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
    }
    
    
    private func generateCalendarEvents() {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        isLoading = true
        
        Task {
            do {
                let response = try await apiService.convertTextToCalendar(text: inputText)
                
                await MainActor.run {
                    isLoading = false
                    
                    if response.eventsFound > 0 {
                        // Try to add events to calendar
                        calendarService.addEventsToCalendar(icsContent: response.icsContent) { success, error in
                            DispatchQueue.main.async {
                                if success {
                                    alertMessage = "Successfully added \(response.eventsFound) event(s) to your calendar!"
                                    inputText = ""
                                } else {
                                    alertMessage = error?.localizedDescription ?? "Failed to add events to calendar"
                                }
                                showAlert = true
                            }
                        }
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
}

#Preview {
    ContentView()
}