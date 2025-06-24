import SwiftUI

struct CountdownView: View {
    @State private var timeRemaining = 5
    @State private var showTimesUp = false

    var body: some View {
        VStack(spacing: 37) {
            if showTimesUp {
                Text("Times up")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.red)
            } else {
                Text("\(timeRemaining)")
                    .font(.system(size: 25, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .padding()
        .background(Color.clear)
        
        .onAppear {
            startCountdown()
        }
    }

    private func startCountdown() {
        timeRemaining = 5
        showTimesUp = false

        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if timeRemaining > 1 {
                timeRemaining -= 1
            } else {
                timer.invalidate()
                timeRemaining = 1
                showTimesUp = true
            }
        }
    }
}

#Preview {
    CountdownView()
}
