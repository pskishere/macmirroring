//
//  MacMirroringApp.swift
//  MacMirroring
//
//  Created by ddxx on 2024/10/18.
//

import SwiftUI

@main
struct MacMirroringApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
