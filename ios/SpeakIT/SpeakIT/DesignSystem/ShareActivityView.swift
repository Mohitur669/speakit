//
//  ShareActivityView.swift
//  SpeakIT
//
//  Reusable UIViewControllerRepresentable wrapper for native iOS UIActivityViewController.
//

import SwiftUI
import UIKit

struct ShareActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
