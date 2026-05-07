//
//  UpdateView.swift
//

import Sparkle
import SwiftUI

struct UpdateView: View {
    private let updater: SPUUpdater

    init(updater: SPUUpdater) {
        self.updater = updater
    }

    var body: some View {
        CheckForUpdatesView(updater: updater)
    }
}
