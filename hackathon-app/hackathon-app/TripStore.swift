import Foundation

struct SavedApplication: Codable, Identifiable, Hashable {
    let applicationId: String
    let intentId: String
    let departureDate: String
    let savedAt: Date

    var id: String { applicationId }
}

@MainActor
final class TripStore {
    static let shared = TripStore()

    private let key = "com.flow.saved_applications"

    func save(applicationId: String, intentId: String, departureDate: String) {
        var list = loadAll()
        list.removeAll { $0.applicationId == applicationId }
        list.append(SavedApplication(
            applicationId: applicationId,
            intentId: intentId,
            departureDate: departureDate,
            savedAt: Date()
        ))
        persist(list)
    }

    func remove(applicationId: String) {
        var list = loadAll()
        list.removeAll { $0.applicationId == applicationId }
        persist(list)
    }

    func loadAll() -> [SavedApplication] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([SavedApplication].self, from: data)) ?? []
    }

    func clearAll() {
        UserDefaults.standard.removeObject(forKey: key)
    }

    private func persist(_ list: [SavedApplication]) {
        guard let data = try? JSONEncoder().encode(list) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
