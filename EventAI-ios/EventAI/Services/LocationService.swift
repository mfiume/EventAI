import Foundation
import CoreLocation

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