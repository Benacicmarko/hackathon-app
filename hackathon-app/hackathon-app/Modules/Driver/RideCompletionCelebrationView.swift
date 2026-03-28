//
//  RideCompletionCelebrationView.swift
//  hackathon-app
//

import SwiftUI

struct RideCompletionCelebrationView: View {
    let ride: ScheduledRide
    @State private var scale: CGFloat = 0.5
    @State private var rotation: Double = 0
    @State private var opacity: Double = 0
    @State private var confettiTrigger = false
    
    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                // Pulsing background circle
                Circle()
                    .fill(
                        ride.phase == .completed
                            ? Color.green.opacity(0.2)
                            : Color.red.opacity(0.2)
                    )
                    .frame(width: 120, height: 120)
                    .scaleEffect(scale)
                
                // Main icon
                Image(systemName: ride.phase.icon)
                    .font(.system(size: 60))
                    .foregroundStyle(ride.phase.accentColor)
                    .rotationEffect(.degrees(rotation))
            }
            .opacity(opacity)
            
            VStack(spacing: 8) {
                Text(ride.phase == .completed ? "Ride Complete!" : "Ride Cancelled")
                    .font(.title.bold())
                    .foregroundStyle(ride.phase.accentColor)
                
                if ride.phase == .completed {
                    Text("Thanks for sharing your commute")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    // Stats
                    HStack(spacing: 32) {
                        statItem(
                            icon: "person.2.fill",
                            value: "\(ride.activePassengerCount)",
                            label: "Passengers"
                        )
                        
                        statItem(
                            icon: "leaf.fill",
                            value: "CO₂",
                            label: "Saved"
                        )
                    }
                    .padding(.top, 8)
                }
            }
            .opacity(opacity)
        }
        .padding()
        .onAppear {
            performAnimation()
        }
    }
    
    @ViewBuilder
    private func statItem(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text(value)
                    .font(.title2.bold())
            }
            .foregroundStyle(.green)
            
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    
    private func performAnimation() {
        // Icon entrance animation
        withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
            scale = 1.0
            opacity = 1.0
        }
        
        // Rotation for success
        if ride.phase == .completed {
            withAnimation(.easeInOut(duration: 0.5).delay(0.2)) {
                rotation = 360
            }
        }
        
        // Trigger confetti
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            confettiTrigger = true
        }
    }
}

// MARK: - Confetti Particle

struct ConfettiParticle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var color: Color
    var scale: CGFloat
    var rotation: Double
}

#Preview("Completed") {
    let ride = ScheduledRide(
        fromLocation: "Zagreb Main",
        toLocation: "Tech Park",
        departureTime: .now,
        availableSeats: 4,
        passengers: [
            RidePassenger(
                name: "Alex",
                pickupLocation: "Station",
                dropoffLocation: "Park",
                status: .checkedIn
            )
        ],
        phase: .completed
    )
    
    return RideCompletionCelebrationView(ride: ride)
}

#Preview("Cancelled") {
    let ride = ScheduledRide(
        fromLocation: "Zagreb Main",
        toLocation: "Tech Park",
        departureTime: .now,
        availableSeats: 4,
        phase: .cancelled
    )
    
    return RideCompletionCelebrationView(ride: ride)
}
