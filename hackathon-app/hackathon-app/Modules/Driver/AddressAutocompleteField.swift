//
//  AddressAutocompleteField.swift
//  hackathon-app
//

import SwiftUI

struct AddressAutocompleteField: View {
    let title: String
    @Binding var text: String
    let placesService: GooglePlacesService
    
    @State private var predictions: [PlacePrediction] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField(title, text: $text)
                .textContentType(.fullStreetAddress)
                .focused($isFocused)
                .onChange(of: text) { oldValue, newValue in
                    searchTask?.cancel()
                    
                    guard !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        predictions = []
                        return
                    }
                    
                    // Debounce the search
                    searchTask = Task {
                        try? await Task.sleep(for: .milliseconds(300))
                        
                        guard !Task.isCancelled else { return }
                        
                        await performSearch(query: newValue)
                    }
                }
                .onChange(of: isFocused) { oldValue, newValue in
                    if !newValue {
                        // Hide suggestions when field loses focus
                        Task {
                            try? await Task.sleep(for: .milliseconds(200))
                            predictions = []
                        }
                    }
                }
            
            // Suggestions dropdown
            if !predictions.isEmpty && isFocused {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(predictions) { prediction in
                        Button {
                            text = prediction.description
                            predictions = []
                            isFocused = false
                        } label: {
                            HStack {
                                Image(systemName: "location.fill")
                                    .foregroundStyle(.secondary)
                                    .font(.caption)
                                
                                Text(prediction.description)
                                    .font(.body)
                                    .foregroundStyle(.primary)
                                    .multilineTextAlignment(.leading)
                                
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        
                        if prediction.id != predictions.last?.id {
                            Divider()
                        }
                    }
                }
                .background(Color(.systemBackground))
                .cornerRadius(8)
                .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                .padding(.top, 4)
            }
        }
    }
    
    private func performSearch(query: String) async {
        isSearching = true
        defer { isSearching = false }
        
        do {
            predictions = try await placesService.fetchPredictions(for: query)
        } catch {
            print("Error fetching predictions: \(error.localizedDescription)")
            predictions = []
        }
    }
}

#Preview {
    @Previewable @State var address = ""
    let service = GooglePlacesService(apiKey: "YOUR_API_KEY")
    
    Form {
        Section("Address") {
            AddressAutocompleteField(
                title: "From",
                text: $address,
                placesService: service
            )
        }
    }
}
