//
//  UIApplication+TopViewController.swift
//  hackathon-app
//

import UIKit

extension UIApplication {
    @MainActor
    func topMostViewController() -> UIViewController? {
        let scene = connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
            ?? connectedScenes.compactMap { $0 as? UIWindowScene }.first

        guard let windowScene = scene else { return nil }

        let root = windowScene.windows.first(where: \.isKeyWindow)?.rootViewController
            ?? windowScene.windows.first?.rootViewController

        return root?.flow_topPresented
    }
}

private extension UIViewController {
    var flow_topPresented: UIViewController {
        if let presented = presentedViewController {
            return presented.flow_topPresented
        }
        if let nav = self as? UINavigationController, let visible = nav.visibleViewController {
            return visible.flow_topPresented
        }
        if let tab = self as? UITabBarController, let selected = tab.selectedViewController {
            return selected.flow_topPresented
        }
        return self
    }
}
