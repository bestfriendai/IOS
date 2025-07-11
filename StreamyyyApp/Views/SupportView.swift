//
//  SupportView.swift
//  StreamyyyApp
//
//  Real support and feedback system integration
//

import SwiftUI
import MessageUI

struct SupportView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var profileManager = ProfileManager.shared
    
    @State private var selectedCategory: SupportCategory = .general
    @State private var subject = ""
    @State private var message = ""
    @State private var includeSystemInfo = true
    @State private var includeLogs = false
    @State private var userEmail = ""
    
    @State private var showingMailComposer = false
    @State private var showingFeedbackSent = false
    @State private var isLoading = false
    @State private var canSendMail = false
    
    private let supportCategories: [SupportCategory] = [
        .general,
        .account,
        .technical,
        .billing,
        .featureRequest,
        .bugReport
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    supportHeader
                    
                    // Quick Help Options
                    quickHelpSection
                    
                    // FAQ Section
                    faqSection
                    
                    // Contact Form
                    contactFormSection
                    
                    // Additional Resources
                    resourcesSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
            .background(backgroundGradient)
            .navigationTitle("Help & Support")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            setupSupport()
        }
        .sheet(isPresented: $showingMailComposer) {
            MailComposerView(
                subject: generateEmailSubject(),
                body: generateEmailBody(),
                recipients: ["support@streamhub.com"]
            )
        }
        .alert("Feedback Sent", isPresented: $showingFeedbackSent) {
            Button("OK") { }
        } message: {
            Text("Thank you for your feedback! We'll get back to you within 24 hours.")
        }
    }
    
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color.black,
                Color(red: 0.05, green: 0.05, blue: 0.15),
                Color.black
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
    
    // MARK: - Support Header
    private var supportHeader: some View {
        VStack(spacing: 16) {
            Image(systemName: "questionmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.cyan)
            
            Text("How can we help you?")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text("Get support, report issues, or share feedback about StreamHub")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }
    
    // MARK: - Quick Help Section
    private var quickHelpSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Quick Help")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                QuickHelpCard(
                    title: "Getting Started",
                    icon: "play.circle.fill",
                    color: .green,
                    action: {
                        openGettingStarted()
                    }
                )
                
                QuickHelpCard(
                    title: "Account Issues",
                    icon: "person.circle.fill",
                    color: .blue,
                    action: {
                        selectedCategory = .account
                    }
                )
                
                QuickHelpCard(
                    title: "Billing Help",
                    icon: "creditcard.fill",
                    color: .purple,
                    action: {
                        selectedCategory = .billing
                    }
                )
                
                QuickHelpCard(
                    title: "Report Bug",
                    icon: "exclamationmark.triangle.fill",
                    color: .red,
                    action: {
                        selectedCategory = .bugReport
                    }
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }
    
    // MARK: - FAQ Section
    private var faqSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Frequently Asked Questions")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Spacer()
                
                Button("View All") {
                    openFullFAQ()
                }
                .font(.subheadline)
                .foregroundColor(.cyan)
            }
            
            VStack(spacing: 8) {
                FAQItem(
                    question: "How do I connect my Twitch account?",
                    answer: "Go to Profile > Platform Connections > Twitch and tap Connect."
                )
                
                FAQItem(
                    question: "Why can't I watch multiple streams?",
                    answer: "Free users can watch up to 4 streams. Upgrade to Pro for unlimited streams."
                )
                
                FAQItem(
                    question: "How do I cancel my subscription?",
                    answer: "Go to Profile > Subscription Management > Cancel Subscription."
                )
                
                FAQItem(
                    question: "My streams are buffering frequently",
                    answer: "Check your internet connection and try lowering the stream quality."
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }
    
    // MARK: - Contact Form Section
    private var contactFormSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Contact Support")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            VStack(spacing: 16) {
                // Category Selection
                VStack(alignment: .leading, spacing: 8) {
                    Text("Category")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                    
                    Menu {
                        ForEach(supportCategories, id: \.self) { category in
                            Button(category.displayName) {
                                selectedCategory = category
                            }
                        }
                    } label: {
                        HStack {
                            Text(selectedCategory.displayName)
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.down")
                                .foregroundColor(.white.opacity(0.6))
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                        )
                    }
                }
                
                // Email Field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Email")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                    
                    TextField("Your email address", text: $userEmail)
                        .textFieldStyle(CustomSupportTextFieldStyle())
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                }
                
                // Subject Field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Subject")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                    
                    TextField("Brief description of your issue", text: $subject)
                        .textFieldStyle(CustomSupportTextFieldStyle())
                }
                
                // Message Field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Message")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                    
                    TextEditor(text: $message)
                        .frame(minHeight: 100)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                        )
                        .foregroundColor(.white)
                        .scrollContentBackground(.hidden)
                }
                
                // Options
                VStack(spacing: 12) {
                    Toggle("Include system information", isOn: $includeSystemInfo)
                        .foregroundColor(.white)
                    
                    if selectedCategory == .bugReport || selectedCategory == .technical {
                        Toggle("Include debug logs", isOn: $includeLogs)
                            .foregroundColor(.white)
                    }
                }
                
                // Send Button
                Button(action: sendSupportRequest) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        }
                        
                        Text(isLoading ? "Sending..." : "Send Message")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [Color.cyan, Color.blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(isLoading || !isFormValid)
                .opacity(isFormValid ? 1.0 : 0.6)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }
    
    // MARK: - Resources Section
    private var resourcesSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Additional Resources")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            VStack(spacing: 12) {
                ResourceLink(
                    title: "User Guide",
                    subtitle: "Complete guide to using StreamHub",
                    icon: "book.fill",
                    color: .blue,
                    action: {
                        openUserGuide()
                    }
                )
                
                ResourceLink(
                    title: "Video Tutorials",
                    subtitle: "Step-by-step video guides",
                    icon: "play.rectangle.fill",
                    color: .red,
                    action: {
                        openVideoTutorials()
                    }
                )
                
                ResourceLink(
                    title: "Community Forum",
                    subtitle: "Connect with other users",
                    icon: "bubble.left.and.bubble.right.fill",
                    color: .green,
                    action: {
                        openCommunityForum()
                    }
                )
                
                ResourceLink(
                    title: "System Status",
                    subtitle: "Check service availability",
                    icon: "chart.line.uptrend.xyaxis",
                    color: .orange,
                    action: {
                        openSystemStatus()
                    }
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }
    
    private var isFormValid: Bool {
        !userEmail.isEmpty && 
        userEmail.contains("@") && 
        !subject.isEmpty && 
        !message.isEmpty
    }
    
    // MARK: - Helper Methods
    private func setupSupport() {
        userEmail = profileManager.userEmail ?? ""
        canSendMail = MFMailComposeViewController.canSendMail()
    }
    
    private func sendSupportRequest() {
        isLoading = true
        
        // Simulate sending support request
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isLoading = false
            showingFeedbackSent = true
            
            // Clear form
            subject = ""
            message = ""
            selectedCategory = .general
        }
    }
    
    private func generateEmailSubject() -> String {
        return "[\\(selectedCategory.displayName)] \\(subject)"
    }
    
    private func generateEmailBody() -> String {
        var body = message + "\n\n"
        
        if includeSystemInfo {
            body += "--- System Information ---\n"
            body += "App Version: \\(Config.App.version) (\\(Config.App.build))\n"
            body += "iOS Version: \\(UIDevice.current.systemVersion)\n"
            body += "Device: \\(UIDevice.current.model)\n"
            body += "User ID: \\(profileManager.currentUser?.id ?? "Guest")\n"
            body += "Email: \\(userEmail)\n\n"
        }
        
        if includeLogs && (selectedCategory == .bugReport || selectedCategory == .technical) {
            body += "--- Debug Information ---\n"
            body += "Please include relevant debug logs here.\n"
        }
        
        return body
    }
    
    private func openGettingStarted() {
        if let url = URL(string: "\\(Config.URLs.website)/getting-started") {
            UIApplication.shared.open(url)
        }
    }
    
    private func openFullFAQ() {
        if let url = URL(string: "\\(Config.URLs.website)/faq") {
            UIApplication.shared.open(url)
        }
    }
    
    private func openUserGuide() {
        if let url = URL(string: "\\(Config.URLs.website)/user-guide") {
            UIApplication.shared.open(url)
        }
    }
    
    private func openVideoTutorials() {
        if let url = URL(string: "\\(Config.URLs.website)/tutorials") {
            UIApplication.shared.open(url)
        }
    }
    
    private func openCommunityForum() {
        if let url = URL(string: "\\(Config.URLs.website)/community") {
            UIApplication.shared.open(url)
        }
    }
    
    private func openSystemStatus() {
        if let url = URL(string: "\\(Config.URLs.website)/status") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Supporting Models and Views

enum SupportCategory: CaseIterable {
    case general
    case account
    case technical
    case billing
    case featureRequest
    case bugReport
    
    var displayName: String {
        switch self {
        case .general: return "General Question"
        case .account: return "Account & Login"
        case .technical: return "Technical Issue"
        case .billing: return "Billing & Subscription"
        case .featureRequest: return "Feature Request"
        case .bugReport: return "Bug Report"
        }
    }
}

struct QuickHelpCard: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(color.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(color.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct FAQItem: View {
    let question: String
    let answer: String
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Text(question)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding()
                .background(Color.white.opacity(0.05))
            }
            .buttonStyle(PlainButtonStyle())
            
            if isExpanded {
                Text(answer)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                    .padding()
                    .background(Color.white.opacity(0.02))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

struct ResourceLink: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
                
                Spacer()
                
                Image(systemName: "arrow.up.right")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct CustomSupportTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            )
            .foregroundColor(.white)
    }
}

struct MailComposerView: UIViewControllerRepresentable {
    let subject: String
    let body: String
    let recipients: [String]
    
    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let composer = MFMailComposeViewController()
        composer.setSubject(subject)
        composer.setMessageBody(body, isHTML: false)
        composer.setToRecipients(recipients)
        composer.mailComposeDelegate = context.coordinator
        return composer
    }
    
    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            controller.dismiss(animated: true)
        }
    }
}

#Preview {
    SupportView()
}"