import SwiftUI

struct SampleBackgroundView: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.97, green: 0.93, blue: 0.89),
                Color(red: 0.99, green: 0.98, blue: 0.95),
                Color(red: 0.91, green: 0.96, blue: 0.93)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
