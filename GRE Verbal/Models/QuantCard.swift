import Foundation

struct QuantCard: Codable, Identifiable {
    let mountain_group: String
    let title: String
    let segments: [QuantSegment]

    var id: String { "\(mountain_group)-\(title)" }
}

struct QuantSegment: Codable {
    let type: QuantSegmentType
    let content: String

    enum QuantSegmentType: String, Codable {
        case text, math, image, svg, divider
    }
}
