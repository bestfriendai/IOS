import SwiftUI

// Test the problematic gradient syntax
struct TestView: View {
    @State private var isEnabled = true
    @State private var isFocused = false
    
    var body: some View {
        VStack {
            // Test the LinearGradient ternary operator
            Rectangle()
                .stroke(
                    isEnabled ? 
                    LinearGradient(colors: [.cyan.opacity(0.5), .purple.opacity(0.5)], startPoint: .leading, endPoint: .trailing) :
                    LinearGradient(colors: [.clear], startPoint: .leading, endPoint: .trailing),
                    lineWidth: 1
                )
                .frame(width: 100, height: 100)
            
            // Test the foregroundStyle
            Image(systemName: "star")
                .foregroundStyle(isFocused ? .cyan : .white.opacity(0.6))
        }
    }
}