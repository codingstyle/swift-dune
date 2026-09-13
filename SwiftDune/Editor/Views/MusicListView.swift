//
//  MusicListView.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 15/04/2026.
//

import Foundation
import SwiftUI

struct MusicListView: View {
    @ObservedObject var viewModel: EditorViewModel
    @State private var selection: Int?

    var body: some View {
        if let music = viewModel.music, music.trackCount > 0 {
            List(selection: $selection) {
                Section("Tracks") {
                    ForEach(0..<music.trackCount, id: \.self) { trackIndex in
                        trackRow(music: music, trackIndex: trackIndex)
                            .tag(trackIndex)
                    }
                }
            }
            .onChange(of: selection, initial: false) { _, newValue in
                if let index = newValue {
                    viewModel.selectedTrackIndex = index
                }
            }
            .onChange(of: viewModel.selectedTrackIndex, initial: true) { _, newValue in
                if selection != newValue {
                    selection = newValue
                }
            }
        } else {
            Text("No music loaded")
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private func trackRow(music: Music, trackIndex: Int) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Track \(trackIndex)")
                    .font(.system(.body, design: .monospaced))
                Text("\(music.trackEvents(at: trackIndex).count) events")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if trackIndex < viewModel.trackMuteStates.count {
                Toggle("", isOn: Binding(
                    get: { !viewModel.trackMuteStates[trackIndex] },
                    set: { _ in viewModel.toggleTrackMute(trackIndex) }
                ))
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
                .help(viewModel.trackMuteStates[trackIndex] ? "Unmute track" : "Mute track")
            }
        }
        .padding(.vertical, 2)
    }
}
