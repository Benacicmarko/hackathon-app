//
//  LoginView.swift
//  hackathon-app
//
//  UI from Stitch “Login” screen (Zagreb Flow PRD design system).
//

import SwiftUI

// MARK: - Design tokens (Stitch / Material dynamic palette)

private enum FlowColor {
    static let surface = Color(hex: 0x131313)
    static let onSurface = Color(hex: 0xE5E2E1)
    static let onSurfaceVariant = Color(hex: 0xC4C5D5)
    static let surfaceContainerLow = Color(hex: 0x1C1B1B)
    static let primary = Color(hex: 0x00E475)
    static let onPrimary = Color(hex: 0x003918)
    static let onPrimaryGradientEnd = Color(hex: 0x00C162)
    static let secondary = Color(hex: 0xB5C4FF)
    static let secondaryContainer = Color(hex: 0x153EA3)
    static let outlineVariant = Color(hex: 0x444653)
}

struct LoginView: View {
    var onGoogleSignIn: () -> Void = {}
    var onEmailContinue: (String) -> Void = { _ in }
    var onSignUp: () -> Void = {}

    @State private var email = ""
    @FocusState private var emailFocused: Bool

    var body: some View {
        ZStack {
            FlowColor.surface.ignoresSafeArea()

            kineticBackground

            VStack(spacing: 0) {
                Spacer(minLength: 24)

                mainColumn

                Spacer(minLength: 16)

                footer
                    .padding(.bottom, 24)
            }
            .padding(.horizontal, 24)
        }
        .preferredColorScheme(.dark)
    }

    private var kineticBackground: some View {
        ZStack {
            RadialGradient(
                colors: [
                    FlowColor.secondaryContainer.opacity(0.35),
                    Color.clear
                ],
                center: UnitPoint(x: 0.25, y: 0.2),
                startRadius: 20,
                endRadius: 320
            )
            .blur(radius: 60)
            .offset(x: -40, y: -80)

            RadialGradient(
                colors: [
                    FlowColor.primary.opacity(0.28),
                    Color.clear
                ],
                center: UnitPoint(x: 0.75, y: 0.55),
                startRadius: 10,
                endRadius: 260
            )
            .blur(radius: 50)
            .offset(x: 30, y: 40)
        }
        .opacity(0.2)
        .allowsHitTesting(false)
    }

    private var mainColumn: some View {
        VStack(spacing: 48) {
            brandBlock

            VStack(spacing: 16) {
                googleButton

                orDivider

                VStack(spacing: 12) {
                    emailField
                    continueButton
                }
            }

            Button(action: onSignUp) {
                Text("Don't have an account? Sign up")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(FlowColor.secondary)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: 448)
        .frame(maxWidth: .infinity)
    }

    private var brandBlock: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [FlowColor.primary, FlowColor.secondaryContainer],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)

                Image(.appLogo)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 120, height: 120)
            }

            VStack(spacing: 8) {
                Text("Zagreb Flow")
                    .font(.system(size: 34, weight: .black, design: .default))
                    .italic()
                    .tracking(-1)
                    .textCase(.uppercase)
                    .foregroundStyle(FlowColor.onSurface)

                Text("Welcome to the Flow")
                    .font(.system(size: 20, weight: .medium))
                    .tracking(-0.3)
                    .foregroundStyle(FlowColor.onSurfaceVariant)
            }
            .multilineTextAlignment(.center)
        }
    }

    private var googleButton: some View {
        Button(action: onGoogleSignIn) {
            HStack(spacing: 12) {
                Image(.googleLogo)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 24, height: 24)

                Text("Continue with Google")
                    .font(.system(size: 17, weight: .bold))
                    .tracking(-0.3)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(FlowColor.onSurface)
            .foregroundStyle(FlowColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.scaleOnPress)
    }

    private var orDivider: some View {
        HStack(spacing: 16) {
            Rectangle()
                .fill(FlowColor.outlineVariant.opacity(0.3))
                .frame(height: 1)
            Text("Or")
                .font(.system(size: 11, weight: .bold))
                .tracking(2)
                .textCase(.uppercase)
                .foregroundStyle(FlowColor.onSurfaceVariant)
            Rectangle()
                .fill(FlowColor.outlineVariant.opacity(0.3))
                .frame(height: 1)
        }
        .padding(.vertical, 8)
    }

    private var emailField: some View {
        ZStack(alignment: .bottom) {
            TextField("Email Address", text: $email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($emailFocused)
                .font(.system(size: 17))
                .foregroundStyle(FlowColor.onSurface)
                .padding(.horizontal, 16)
                .frame(height: 56)
                .background(FlowColor.surfaceContainerLow)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            Rectangle()
                .fill(emailFocused ? FlowColor.primary : Color.clear)
                .frame(height: 2)
                .padding(.horizontal, 4)
                .padding(.bottom, 2)
        }
    }

    private var continueButton: some View {
        Button {
            onEmailContinue(email.trimmingCharacters(in: .whitespacesAndNewlines))
        } label: {
            Text("Continue")
                .font(.system(size: 15, weight: .heavy))
                .tracking(2)
                .textCase(.uppercase)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .foregroundStyle(FlowColor.onPrimary)
                .background(
                    LinearGradient(
                        colors: [FlowColor.primary, FlowColor.onPrimaryGradientEnd],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(color: FlowColor.primary.opacity(0.2), radius: 12, y: 6)
        }
        .buttonStyle(.scaleOnPress)
    }

    private var footer: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                Button("Terms of Service") {}
                    .font(.system(size: 12))
                    .foregroundStyle(FlowColor.onSurfaceVariant)
                Circle()
                    .fill(FlowColor.outlineVariant)
                    .frame(width: 4, height: 4)
                Button("Privacy Policy") {}
                    .font(.system(size: 12))
                    .foregroundStyle(FlowColor.onSurfaceVariant)
            }
            Text("© 2026 Zagreb Flow")
                .font(.system(size: 10, weight: .regular))
                .tracking(2)
                .textCase(.uppercase)
                .foregroundStyle(FlowColor.onSurfaceVariant.opacity(0.5))
        }
        .multilineTextAlignment(.center)
    }
}

// MARK: - Small utilities

private extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

private struct ScaleOnPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

private extension ButtonStyle where Self == ScaleOnPressButtonStyle {
    static var scaleOnPress: ScaleOnPressButtonStyle { ScaleOnPressButtonStyle() }
}

#Preview {
    LoginView()
}
