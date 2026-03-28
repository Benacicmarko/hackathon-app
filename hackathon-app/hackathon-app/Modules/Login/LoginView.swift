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
    @Environment(AppSession.self) private var session

    @State private var email = ""
    @State private var emailFlow: EmailFlow?
    @State private var localHint: String?

    @FocusState private var emailFocused: Bool

    private enum EmailFlow: Identifiable {
        case signIn(String)
        case signUp(String)

        var id: String {
            switch self {
            case .signIn(let e): return "in-\(e)"
            case .signUp(let e): return "up-\(e)"
            }
        }
    }

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

            if session.isAuthBusy {
                ProgressView()
                    .tint(FlowColor.primary)
                    .scaleEffect(1.2)
            }
        }
        .preferredColorScheme(.dark)
        .sheet(item: $emailFlow) { flow in
            switch flow {
            case .signIn(let address):
                EmailPasswordSheet(email: address, mode: .signIn)
            case .signUp(let address):
                EmailPasswordSheet(email: address, mode: .signUp)
            }
        }
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

            authMessages

            Button(action: openSignUp) {
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

    private var authMessages: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let localHint {
                Text(localHint)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(FlowColor.secondary)
            }
            if let err = session.authError {
                Text(err)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color(red: 1, green: 0.4, blue: 0.45))
                Button("Dismiss") {
                    session.clearAuthError()
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(FlowColor.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var googleButton: some View {
        Button {
            localHint = nil
            Task { await session.signInWithGoogle() }
        } label: {
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
        .disabled(session.isAuthBusy)
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
            openEmailSignIn()
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
        .disabled(session.isAuthBusy)
    }

    private func openEmailSignIn() {
        session.clearAuthError()
        localHint = nil
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.contains("@"), trimmed.contains(".") else {
            localHint = "Enter a valid email address."
            return
        }
        emailFlow = .signIn(trimmed)
    }

    private func openSignUp() {
        session.clearAuthError()
        localHint = nil
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.contains("@"), trimmed.contains(".") else {
            localHint = "Enter your email above, then tap Sign up."
            return
        }
        emailFlow = .signUp(trimmed)
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
        .environment(AppSession())
}
