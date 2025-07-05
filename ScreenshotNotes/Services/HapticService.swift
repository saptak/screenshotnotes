import UIKit

protocol HapticServiceProtocol {
    func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle)
    func notification(_ type: UINotificationFeedbackGenerator.FeedbackType)
    func selectionChanged()
}

class HapticService: HapticServiceProtocol {
    static let shared = HapticService()
    
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private let notification = UINotificationFeedbackGenerator()
    private let selection = UISelectionFeedbackGenerator()
    
    private init() {
        // Prepare generators for better responsiveness
        impactLight.prepare()
        impactMedium.prepare()
        impactHeavy.prepare()
        notification.prepare()
        selection.prepare()
    }
    
    func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        switch style {
        case .light:
            impactLight.impactOccurred()
            impactLight.prepare()
        case .medium:
            impactMedium.impactOccurred()
            impactMedium.prepare()
        case .heavy:
            impactHeavy.impactOccurred()
            impactHeavy.prepare()
        case .rigid:
            if #available(iOS 13.0, *) {
                let rigidGenerator = UIImpactFeedbackGenerator(style: .rigid)
                rigidGenerator.impactOccurred()
                rigidGenerator.prepare()
            } else {
                impactHeavy.impactOccurred()
                impactHeavy.prepare()
            }
        case .soft:
            if #available(iOS 13.0, *) {
                let softGenerator = UIImpactFeedbackGenerator(style: .soft)
                softGenerator.impactOccurred()
                softGenerator.prepare()
            } else {
                impactLight.impactOccurred()
                impactLight.prepare()
            }
        @unknown default:
            impactMedium.impactOccurred()
            impactMedium.prepare()
        }
    }
    
    func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        notification.notificationOccurred(type)
        notification.prepare()
    }
    
    func selectionChanged() {
        selection.selectionChanged()
        selection.prepare()
    }
}
