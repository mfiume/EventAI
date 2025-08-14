import SwiftUI

// MARK: - Error Types
enum AppError {
    case networkTimeout
    case serverUnavailable  
    case subscriptionFailed
    case apiQuotaExceeded
    case invalidResponse
    case permissionDenied
    case unknown(String)
    
    var title: String {
        switch self {
        case .networkTimeout:
            return "Connection Timeout"
        case .serverUnavailable:
            return "Service Unavailable"
        case .subscriptionFailed:
            return "Subscription Error"
        case .apiQuotaExceeded:
            return "Daily Limit Reached"
        case .invalidResponse:
            return "Unexpected Response"
        case .permissionDenied:
            return "Permission Required"
        case .unknown:
            return "Something Went Wrong"
        }
    }
    
    var userMessage: String {
        switch self {
        case .networkTimeout:
            return "The request is taking longer than expected. Please check your connection and try again."
        case .serverUnavailable:
            return "Our service is temporarily unavailable. Please try again in a few moments."
        case .subscriptionFailed:
            return "Unable to process your subscription. Please try again or contact support if the issue persists."
        case .apiQuotaExceeded:
            return "You've reached your daily limit. Upgrade to Premium for more conversions or try again tomorrow."
        case .invalidResponse:
            return "We received an unexpected response. Please try again."
        case .permissionDenied:
            return "Additional permissions are required to complete this action."
        case .unknown(let details):
            // Hide technical details from user but log them for debugging
            return "An unexpected error occurred. Please try again."
        }
    }
    
    var icon: String {
        switch self {
        case .networkTimeout:
            return "wifi.slash"
        case .serverUnavailable:
            return "server.rack"
        case .subscriptionFailed:
            return "creditcard.trianglebadge.exclamationmark"
        case .apiQuotaExceeded:
            return "gauge.high"
        case .invalidResponse:
            return "questionmark.circle"
        case .permissionDenied:
            return "lock.shield"
        case .unknown:
            return "exclamationmark.triangle"
        }
    }
    
    var primaryAction: ErrorAction? {
        switch self {
        case .networkTimeout:
            return ErrorAction(title: "Try Again", style: .primary)
        case .serverUnavailable:
            return ErrorAction(title: "Retry", style: .primary)
        case .subscriptionFailed:
            return ErrorAction(title: "Try Again", style: .primary)
        case .apiQuotaExceeded:
            return ErrorAction(title: "Upgrade to Premium", style: .premium)
        case .invalidResponse:
            return ErrorAction(title: "Try Again", style: .primary)
        case .permissionDenied:
            return ErrorAction(title: "Grant Permission", style: .primary)
        case .unknown:
            return ErrorAction(title: "Try Again", style: .primary)
        }
    }
    
    var secondaryAction: ErrorAction? {
        switch self {
        case .subscriptionFailed:
            return ErrorAction(title: "Contact Support", style: .secondary)
        case .apiQuotaExceeded:
            return ErrorAction(title: "Try Tomorrow", style: .secondary)
        default:
            return ErrorAction(title: "Cancel", style: .secondary)
        }
    }
}

struct ErrorAction {
    let title: String
    let style: Style
    
    enum Style {
        case primary
        case secondary
        case premium
        case destructive
    }
}

// MARK: - Error Banner View
struct ErrorBannerView: View {
    let error: AppError
    let onPrimaryAction: (() -> Void)?
    let onSecondaryAction: (() -> Void)?
    let onDismiss: () -> Void
    
    @State private var isVisible = false
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: error.icon)
                    .font(.title2)
                    .foregroundColor(.red)
                    .frame(width: 24, height: 24)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(error.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(error.userMessage)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            if error.primaryAction != nil || error.secondaryAction != nil {
                HStack(spacing: 8) {
                    if let secondary = error.secondaryAction {
                        Button(secondary.title) {
                            onSecondaryAction?()
                        }
                        .buttonStyle(ErrorButtonStyle(style: secondary.style))
                    }
                    
                    if let primary = error.primaryAction {
                        Button(primary.title) {
                            onPrimaryAction?()
                        }
                        .buttonStyle(ErrorButtonStyle(style: primary.style))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        .padding(.horizontal, 16)
        .scaleEffect(isVisible ? 1 : 0.95)
        .opacity(isVisible ? 1 : 0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isVisible)
        .onAppear {
            isVisible = true
        }
    }
}

// MARK: - Error Button Style
struct ErrorButtonStyle: ButtonStyle {
    let style: ErrorAction.Style
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(backgroundColor)
            .foregroundColor(foregroundColor)
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
    
    private var backgroundColor: Color {
        switch style {
        case .primary:
            return .blue
        case .secondary:
            return Color(.systemGray5)
        case .premium:
            return .purple
        case .destructive:
            return .red
        }
    }
    
    private var foregroundColor: Color {
        switch style {
        case .primary, .premium, .destructive:
            return .white
        case .secondary:
            return .primary
        }
    }
}

// MARK: - Error Sheet View
struct ErrorSheetView: View {
    let error: AppError
    let onPrimaryAction: (() -> Void)?
    let onSecondaryAction: (() -> Void)?
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                Image(systemName: error.icon)
                    .font(.system(size: 48))
                    .foregroundColor(.red)
                
                VStack(spacing: 8) {
                    Text(error.title)
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                    
                    Text(error.userMessage)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.top, 32)
            
            Spacer()
            
            VStack(spacing: 12) {
                if let primary = error.primaryAction {
                    Button(primary.title) {
                        onPrimaryAction?()
                    }
                    .buttonStyle(ErrorButtonStyle(style: primary.style))
                    .frame(maxWidth: .infinity)
                }
                
                if let secondary = error.secondaryAction {
                    Button(secondary.title) {
                        onSecondaryAction?()
                    }
                    .buttonStyle(ErrorButtonStyle(style: secondary.style))
                    .frame(maxWidth: .infinity)
                }
                
                Button("Close") {
                    onDismiss()
                }
                .buttonStyle(ErrorButtonStyle(style: .secondary))
                .frame(maxWidth: .infinity)
            }
            .padding(.bottom, 32)
        }
        .padding(.horizontal, 24)
        .background(Color(.systemBackground))
    }
}

// MARK: - Error Manager
@MainActor
class ErrorManager: ObservableObject {
    @Published var currentError: AppError?
    @Published var showBanner = false
    @Published var showSheet = false
    
    func show(_ error: AppError, as presentation: ErrorPresentation = .banner) {
        currentError = error
        
        switch presentation {
        case .banner:
            showBanner = true
            // Auto-dismiss banner after 5 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                self.dismiss()
            }
        case .sheet:
            showSheet = true
        }
    }
    
    func dismiss() {
        showBanner = false
        showSheet = false
        currentError = nil
    }
    
    // Convert common error types to AppError
    static func convert(error: Error) -> AppError {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut:
                return .networkTimeout
            case .notConnectedToInternet, .networkConnectionLost:
                return .serverUnavailable
            default:
                return .unknown(urlError.localizedDescription)
            }
        }
        
        // Handle RevenueCat/StoreKit errors
        if error.localizedDescription.lowercased().contains("purchase") ||
           error.localizedDescription.lowercased().contains("subscription") ||
           error.localizedDescription.lowercased().contains("billing") {
            return .subscriptionFailed
        }
        
        // Add more error type conversions as needed
        return .unknown(error.localizedDescription)
    }
}

enum ErrorPresentation {
    case banner
    case sheet
}

// MARK: - View Extensions
extension View {
    func errorBanner(errorManager: ErrorManager, 
                    onPrimaryAction: (() -> Void)? = nil,
                    onSecondaryAction: (() -> Void)? = nil) -> some View {
        ZStack(alignment: .top) {
            self
            
            if errorManager.showBanner, let error = errorManager.currentError {
                VStack {
                    ErrorBannerView(
                        error: error,
                        onPrimaryAction: onPrimaryAction,
                        onSecondaryAction: onSecondaryAction,
                        onDismiss: { errorManager.dismiss() }
                    )
                    Spacer()
                }
                .zIndex(1000)
            }
        }
    }
    
    func errorSheet(errorManager: ErrorManager,
                   onPrimaryAction: (() -> Void)? = nil,
                   onSecondaryAction: (() -> Void)? = nil) -> some View {
        sheet(isPresented: $errorManager.showSheet) {
            if let error = errorManager.currentError {
                ErrorSheetView(
                    error: error,
                    onPrimaryAction: onPrimaryAction,
                    onSecondaryAction: onSecondaryAction,
                    onDismiss: { errorManager.dismiss() }
                )
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
            }
        }
    }
}

// MARK: - APIError Extension  
enum APIError: LocalizedError {
    case invalidURL
    case encodingError
    case invalidResponse
    case serverError(Int)
    case networkError(Error)
    case timeout
    case unauthorized
    case quotaExceeded
    case serverUnavailable
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .encodingError:
            return "Failed to encode request"
        case .invalidResponse:
            return "Invalid server response"
        case .serverError(let code):
            return "Server error: \(code)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .timeout:
            return "Request timed out"
        case .unauthorized:
            return "Authentication failed"
        case .quotaExceeded:
            return "Daily limit exceeded"
        case .serverUnavailable:
            return "Service temporarily unavailable"
        }
    }
    
    // Convert APIError to AppError for presentation
    func toAppError() -> AppError {
        switch self {
        case .timeout:
            return .networkTimeout
        case .serverUnavailable, .serverError:
            return .serverUnavailable
        case .unauthorized:
            return .permissionDenied
        case .quotaExceeded:
            return .apiQuotaExceeded
        case .invalidResponse, .encodingError, .invalidURL:
            return .invalidResponse
        case .networkError(let error):
            return .unknown(error.localizedDescription)
        }
    }
}