//
//  RidePhaseProgressView.swift
//  hackathon-app
//

import SwiftUI

struct RidePhaseProgressView: View {
    let currentPhase: DriverRidePhase
    @Namespace private var progressAnimation
    
    // Ordered phases for progress visualization
    private let progressPhases: [DriverRidePhase] = [
        .scheduledRide,
        .boarding,
        .inProgress,
        .completed
    ]
    
    private var currentIndex: Int {
        progressPhases.firstIndex(of: currentPhase) ?? 0
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Progress bar
            HStack(spacing: 0) {
                ForEach(Array(progressPhases.enumerated()), id: \.offset) { index, phase in
                    progressSegment(for: phase, at: index)
                    
                    if index < progressPhases.count - 1 {
                        connector(isActive: index < currentIndex)
                    }
                }
            }
            
            // Current phase label
            HStack {
                Image(systemName: currentPhase.icon)
                    .font(.title2)
                    .matchedGeometryEffect(id: "phaseIcon", in: progressAnimation)
                
                Text(currentPhase.displayTitle)
                    .font(.headline)
            }
            .foregroundStyle(currentPhase.accentColor)
            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: currentPhase)
        }
        .padding()
    }
    
    @ViewBuilder
    private func progressSegment(for phase: DriverRidePhase, at index: Int) -> some View {
        let isActive = index <= currentIndex
        let isCurrent = index == currentIndex
        
        Circle()
            .fill(isActive ? phase.accentColor : Color.gray.opacity(0.3))
            .frame(width: isCurrent ? 32 : 24, height: isCurrent ? 32 : 24)
            .overlay {
                if isActive {
                    Image(systemName: isCurrent ? phase.icon : "checkmark")
                        .font(.caption)
                        .foregroundStyle(.white)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: currentPhase)
    }
    
    @ViewBuilder
    private func connector(isActive: Bool) -> some View {
        Rectangle()
            .fill(isActive ? Color.green : Color.gray.opacity(0.3))
            .frame(height: 3)
            .frame(maxWidth: .infinity)
            .animation(.easeInOut(duration: 0.4), value: isActive)
    }
}

// MARK: - Compact variant for cards

struct CompactRidePhaseView: View {
    let currentPhase: DriverRidePhase
    var showAnimation: Bool = true
    
    @State private var animationScale: CGFloat = 1.0
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: currentPhase.icon)
                .font(.caption)
                .scaleEffect(animationScale)
            
            Text(currentPhase.displayTitle)
                .font(.subheadline.weight(.semibold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(currentPhase.accentColor, in: Capsule())
        .onChange(of: currentPhase) { oldValue, newValue in
            guard showAnimation else { return }
            
            // Pulse animation on phase change
            withAnimation(.easeOut(duration: 0.2)) {
                animationScale = 1.3
            }
            
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6).delay(0.2)) {
                animationScale = 1.0
            }
        }
    }
}

#Preview("Progress View - Scheduled") {
    VStack(spacing: 40) {
        RidePhaseProgressView(currentPhase: .scheduledRide)
        RidePhaseProgressView(currentPhase: .boarding)
        RidePhaseProgressView(currentPhase: .inProgress)
        RidePhaseProgressView(currentPhase: .completed)
    }
    .padding()
}

#Preview("Compact Badge") {
    VStack(spacing: 20) {
        CompactRidePhaseView(currentPhase: .scheduledRide)
        CompactRidePhaseView(currentPhase: .boarding)
        CompactRidePhaseView(currentPhase: .inProgress)
        CompactRidePhaseView(currentPhase: .completed)
    }
    .padding()
}
