import SwiftUI
import os

struct LockView: View {
    @EnvironmentObject private var securityService: SecurityService
    @State private var isAuthenticating = false
    @State private var showingPinEntry = false
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
                    
                    if securityService.canUseBiometrics {
                        Text("Use Face ID or Touch ID to unlock")
                            .foregroundColor(.secondary)
                        
                        Button(action: { authenticate() }) {
                            Label("Unlock with Face ID/Touch ID", systemImage: "faceid")
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.accentColor)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        .padding(.horizontal, 40)
                        .disabled(isAuthenticating)
                        
                        if securityService.hasFallbackPin {
                            Button("Use PIN Instead") {
                                showingPinEntry = true
                            }
                            .padding(.top)
                        }
                    } else if securityService.hasFallbackPin {
                        Text("Enter your PIN to unlock")
                            .foregroundColor(.secondary)
                        
                        Button(action: { showingPinEntry = true }) {
                            Label("Enter PIN", systemImage: "key.fill")
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.accentColor)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        .padding(.horizontal, 40)
                    }
                    
                    if let error = securityService.authenticationError {
                        Text(error)
                            .foregroundColor(.red)
                            .padding(.top)
                    }
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .onAppear {
                logger.debug("Screen size: \(geometry.size.width) x \(geometry.size.height)")
                logger.debug("Safe area insets: top: \(geometry.safeAreaInsets.top), bottom: \(geometry.safeAreaInsets.bottom), left: \(geometry.safeAreaInsets.leading), right: \(geometry.safeAreaInsets.trailing)")
                
                if securityService.canUseBiometrics {
                    authenticate()
                } else if securityService.hasFallbackPin {
                    showingPinEntry = true
                }
            }
            .onChange(of: geometry.size) { oldSize, newSize in
                logger.debug("Screen size changed to: \(newSize.width) x \(newSize.height)")
            }
            .sheet(isPresented: $showingPinEntry) {
                PinEntryView(isPresented: $showingPinEntry)
                    .interactiveDismissDisabled()
            }
        }
        .ignoresSafeArea()
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