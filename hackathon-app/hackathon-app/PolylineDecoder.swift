import CoreLocation

/// Decodes a Google-encoded polyline string into an array of coordinates.
/// Algorithm: https://developers.google.com/maps/documentation/utilities/polylinealgorithm
enum PolylineDecoder {
    static func decode(_ encoded: String) -> [CLLocationCoordinate2D] {
        var coordinates: [CLLocationCoordinate2D] = []
        let bytes = Array(encoded.utf8)
        var index = 0
        var lat: Int32 = 0
        var lng: Int32 = 0

        while index < bytes.count {
            lat += decodeValue(bytes: bytes, index: &index)
            lng += decodeValue(bytes: bytes, index: &index)
            coordinates.append(
                CLLocationCoordinate2D(
                    latitude: Double(lat) / 1e5,
                    longitude: Double(lng) / 1e5
                )
            )
        }
        return coordinates
    }

    private static func decodeValue(bytes: [UInt8], index: inout Int) -> Int32 {
        var result: Int32 = 0
        var shift: Int32 = 0
        var byte: Int32

        repeat {
            byte = Int32(bytes[index]) - 63
            index += 1
            result |= (byte & 0x1F) << shift
            shift += 5
        } while byte >= 0x20

        return (result & 1) != 0 ? ~(result >> 1) : (result >> 1)
    }
}
