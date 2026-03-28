//
//  EmailPasswordSheet.swift
//  hackathon-app
//

import SwiftUI

struct EmailPasswordSheet: View {
    enum Mode {
        case signIn
        case signUp
    }

    let email: String
    let mode: Mode

    @Environment(AppSession.self) private var session
    @Environment(\.dismiss) private var dismiss

    @State private var password = ""
    @State private var confirmPassword = ""
    @FocusState private var focusedField: Field?

    private enum Field {
        case password
        case confirm
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(email)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Email")
                }

                Section {
                    SecureField(mode == .signUp ? "Password (min 6 characters)" : "Password", text: $password)
                        .textContentType(mode == .signUp ? .newPassword : .password)
                        .focused($focusedField, equals: .password)

                    if mode == .signUp {
                        SecureField("Confirm password", text: $confirmPassword)
                            .textContentType(.newPassword)
                            .focused($focusedField, equals: .confirm)
                    }
                } header: {
                    Text(mode == .signUp ? "Create password" : "Sign in")
                }
            }
            .navigationTitle(mode == .signUp ? "Sign up" : "Sign in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(mode == .signUp ? "Create account" : "Sign in") {
                        Task { await submit() }
                    }
                    .disabled(!canSubmit || session.isAuthBusy)
                }
            }
            .overlay {
                if session.isAuthBusy {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.ultraThinMaterial)
                }
            }
            .onAppear { focusedField = .password }
        }
    }

    private var canSubmit: Bool {
        guard password.count >= 6 else { return false }
        if mode == .signUp {
            return password == confirmPassword
        }
        return true
    }

    private func submit() async {
        switch mode {
        case .signIn:
            await session.signInWithEmail(email: email, password: password)
        case .signUp:
            await session.signUpWithEmail(email: email, password: password)
        }
        if session.authError == nil {
            dismiss()
        }
    }
}
