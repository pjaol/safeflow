import SwiftUI

struct LockView: View {
    @EnvironmentObject private var securityService: SecurityService
    @State private var isAuthenticating = false
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Spacer()
            
            Image(systemName: "lock.shield")
                .font(.system(size: 60))
                .foregroundColor(.accentColor)
            
            Text("SafeFlow is Locked")
                .font(.title2)
                .bold()
            
            Text("Use Face ID or Touch ID to unlock")
                .foregroundColor(.secondary)
            
            Button(action: { authenticate() }) {
                Label("Unlock", systemImage: "faceid")
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.horizontal)
            .disabled(isAuthenticating)
            
            Spacer()
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemBackground))
        .ignoresSafeArea()
        .task {
            authenticate()
        }
    }
    
    private func authenticate() {
        guard !isAuthenticating else { return }
        
        isAuthenticating = true
        Task {
            let success = await securityService.authenticateWithBiometrics()
            isAuthenticating = false
            
            if !success {
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.error)
            }
        }
    }
} 