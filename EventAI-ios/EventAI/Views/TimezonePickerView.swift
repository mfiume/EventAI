import SwiftUI

struct TimezonePickerView: View {
    @Binding var selectedTimezone: TimeZone
    @Environment(\.presentationMode) var presentationMode
    @State private var searchText = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
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
                .listStyle(PlainListStyle())
                .edgesIgnoringSafeArea(.horizontal)
            }
            .navigationTitle("Select Timezone")
            .navigationBarItems(
                trailing: Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
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

struct TimezoneRow: View {
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
                .padding(.trailing, 8)
            
            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundColor(.blue)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .padding(.vertical, 2)
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

#Preview {
    TimezonePickerView(selectedTimezone: .constant(TimeZone.current))
}