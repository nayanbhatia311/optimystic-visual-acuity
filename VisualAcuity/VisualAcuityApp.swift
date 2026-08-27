//
//  VisualAcuityApp.swift
//  VisualAcuity
//
//  Created by Nayan Bhatia on 3/28/26.
//

import SwiftUI

@main
struct VisualAcuityApp: App {
    @StateObject private var viewModel = VisualAcuityAppViewModel()

    var body: some Scene {
        WindowGroup {
            RootView(viewModel: viewModel)
        }
    }
}
