import SwiftUI
import os

struct LockView: View {
    @EnvironmentObject private var securityService: SecurityService
    @State private var isAuthenticating = false
    private let logger = Logger(subsystem: "com.thevgergroup.safeflow", category: "LockView")
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color(uiColor: .systemBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
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
                    .padding(.horizontal, 40)
                    .disabled(isAuthenticating)
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .onAppear {
                logger.debug("Screen size: \(geometry.size.width) x \(geometry.size.height)")
                logger.debug("Safe area insets: top: \(geometry.safeAreaInsets.top), bottom: \(geometry.safeAreaInsets.bottom), left: \(geometry.safeAreaInsets.leading), right: \(geometry.safeAreaInsets.trailing)")
            }
            .onChange(of: geometry.size) { oldSize, newSize in
                logger.debug("Screen size changed to: \(newSize.width) x \(newSize.height)")
            }
        }
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