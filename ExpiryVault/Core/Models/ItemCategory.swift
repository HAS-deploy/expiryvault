import SwiftUI

enum ItemCategory: String, CaseIterable, Identifiable, Codable {
    case travel, id, insurance, vehicle, work, health, pet, home, membership, warranty, custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .travel:     return "Travel"
        case .id:         return "ID"
        case .insurance:  return "Insurance"
        case .vehicle:    return "Vehicle"
        case .work:       return "Work"
        case .health:     return "Health"
        case .pet:        return "Pet"
        case .home:       return "Home"
        case .membership: return "Membership"
        case .warranty:   return "Warranty"
        case .custom:     return "Other"
        }
    }

    var symbol: String {
        switch self {
        case .travel:     return "airplane"
        case .id:         return "person.text.rectangle.fill"
        case .insurance:  return "shield.lefthalf.filled"
        case .vehicle:    return "car.fill"
        case .work:       return "briefcase.fill"
        case .health:     return "heart.fill"
        case .pet:        return "pawprint.fill"
        case .home:       return "house.fill"
        case .membership: return "creditcard.fill"
        case .warranty:   return "seal.fill"
        case .custom:     return "tag.fill"
        }
    }

    /// Soft accent color used for the category chip. All palettes stay
    /// within the same trust-tone range (blues/teals/greens/soft oranges).
    var tint: Color {
        switch self {
        case .travel:     return Color(red: 0.22, green: 0.55, blue: 0.93)
        case .id:         return Color(red: 0.11, green: 0.44, blue: 0.73)
        case .insurance:  return Color(red: 0.17, green: 0.60, blue: 0.55)
        case .vehicle:    return Color(red: 0.34, green: 0.52, blue: 0.64)
        case .work:       return Color(red: 0.45, green: 0.38, blue: 0.72)
        case .health:     return Color(red: 0.88, green: 0.34, blue: 0.42)
        case .pet:        return Color(red: 0.92, green: 0.56, blue: 0.32)
        case .home:       return Color(red: 0.24, green: 0.56, blue: 0.38)
        case .membership: return Color(red: 0.34, green: 0.52, blue: 0.64)
        case .warranty:   return Color(red: 0.62, green: 0.48, blue: 0.25)
        case .custom:     return Color.gray
        }
    }
}
