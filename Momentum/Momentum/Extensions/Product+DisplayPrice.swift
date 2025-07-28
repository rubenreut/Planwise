import StoreKit
import Foundation

extension Product {
    var displayPrice: String {
        // Use StoreKit's built-in price formatting
        // This automatically handles currency, locale, and formatting
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = priceFormatStyle.locale
        
        return formatter.string(from: price as NSNumber) ?? priceFormatStyle.format(price)
    }
}