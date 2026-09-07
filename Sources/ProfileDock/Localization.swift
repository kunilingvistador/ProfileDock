import Foundation

func L(_ english: String, _ russian: String) -> String {
    Locale.preferredLanguages.first?.lowercased().hasPrefix("ru") == true ? russian : english
}
