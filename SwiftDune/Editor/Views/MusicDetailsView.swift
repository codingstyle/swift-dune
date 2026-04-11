//
//  MusicDetailsView.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 06/02/2026.
//

import Foundation
import SwiftUI

// MARK: - Note span model for timeline visualization

struct MusicNoteSpan {
    var startTick: UInt32
    var endTick: UInt32
    var noteNumber: UInt8
    var velocity: UInt8
}

// MARK: - Timeline view for a single track

struct MusicTrackTimelineView: View {
    let events: [HeradEvent]
    let maxTicks: UInt32
    let pixelsPerTick: CGFloat
    let isMuted: Bool

    var body: some View {
        let noteSpans = Self.computeNoteSpans(from: events, maxTicks: maxTicks)
        let noteRange = Self.computeNoteRange(from: noteSpans)

        Canvas { context, size in
            // Background
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .color(Color(nsColor: .controlBackgroundColor))
            )

            guard !noteSpans.isEmpty else { return }

            let padding: CGFloat = 3
            let availableHeight = size.height - padding * 2
            let range = max(noteRange.1 - noteRange.0, 1)
            let barHeight = max(min(availableHeight / CGFloat(range + 1), 6), 2)

            var spanIdx = 0
            while spanIdx < noteSpans.count {
                let span = noteSpans[spanIdx]
                let posX = CGFloat(span.startTick) * pixelsPerTick
                let width = max(CGFloat(span.endTick - span.startTick) * pixelsPerTick, 1.5)
                let normalizedNote = range > 0
                    ? CGFloat(Int(span.noteNumber) - noteRange.0) / CGFloat(range)
                    : 0.5
                let posY = padding + (1.0 - normalizedNote) * (availableHeight - barHeight)

                let rect = CGRect(x: posX, y: posY, width: width, height: barHeight)
                let hue = Double(span.noteNumber % 12) / 12.0
                let color: Color = isMuted
                    ? Color(hue: 0, saturation: 0, brightness: 0.65)
                    : Color(hue: hue, saturation: 0.65, brightness: 0.85)
                context.fill(Path(roundedRect: rect, cornerRadius: 1), with: .color(color))
                spanIdx += 1
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    /// Pairs noteOn/noteOff events into spans for piano-roll visualization
    static func computeNoteSpans(from events: [HeradEvent], maxTicks: UInt32) -> [MusicNoteSpan] {
        var activeNoteNumbers: [UInt8] = []
        var activeStartTicks: [UInt32] = []
        var activeVelocities: [UInt8] = []
        var spans: [MusicNoteSpan] = []

        var eventIdx = 0
        while eventIdx < events.count {
            let event = events[eventIdx]

            switch event.type {
            case .noteOn(let note, let vel, _):
                // Close any existing note with same number
                var searchIdx = 0
                while searchIdx < activeNoteNumbers.count {
                    if activeNoteNumbers[searchIdx] == note {
                        spans.append(MusicNoteSpan(
                            startTick: activeStartTicks[searchIdx],
                            endTick: event.ticks,
                            noteNumber: note,
                            velocity: activeVelocities[searchIdx]
                        ))
                        activeNoteNumbers.remove(at: searchIdx)
                        activeStartTicks.remove(at: searchIdx)
                        activeVelocities.remove(at: searchIdx)
                        break
                    }
                    searchIdx += 1
                }
                activeNoteNumbers.append(note)
                activeStartTicks.append(event.ticks)
                activeVelocities.append(vel)

            case .noteOff(let note, _):
                var searchIdx = 0
                while searchIdx < activeNoteNumbers.count {
                    if activeNoteNumbers[searchIdx] == note {
                        spans.append(MusicNoteSpan(
                            startTick: activeStartTicks[searchIdx],
                            endTick: event.ticks,
                            noteNumber: note,
                            velocity: activeVelocities[searchIdx]
                        ))
                        activeNoteNumbers.remove(at: searchIdx)
                        activeStartTicks.remove(at: searchIdx)
                        activeVelocities.remove(at: searchIdx)
                        break
                    }
                    searchIdx += 1
                }

            case .endTrack:
                var closeIdx = 0
                while closeIdx < activeNoteNumbers.count {
                    spans.append(MusicNoteSpan(
                        startTick: activeStartTicks[closeIdx],
                        endTick: event.ticks,
                        noteNumber: activeNoteNumbers[closeIdx],
                        velocity: activeVelocities[closeIdx]
                    ))
                    closeIdx += 1
                }
                activeNoteNumbers.removeAll()
                activeStartTicks.removeAll()
                activeVelocities.removeAll()

            default:
                break
            }

            eventIdx += 1
        }

        // Close remaining active notes at maxTicks
        var remainIdx = 0
        while remainIdx < activeNoteNumbers.count {
            spans.append(MusicNoteSpan(
                startTick: activeStartTicks[remainIdx],
                endTick: maxTicks,
                noteNumber: activeNoteNumbers[remainIdx],
                velocity: activeVelocities[remainIdx]
            ))
            remainIdx += 1
        }

        return spans
    }

    /// Returns (minNote, maxNote) from spans
    static func computeNoteRange(from spans: [MusicNoteSpan]) -> (Int, Int) {
        guard !spans.isEmpty else { return (60, 72) }

        var minNote = 127
        var maxNote = 0

        var idx = 0
        while idx < spans.count {
            let note = Int(spans[idx].noteNumber)
            if note < minNote { minNote = note }
            if note > maxNote { maxNote = note }
            idx += 1
        }

        return (minNote, maxNote)
    }
}

// MARK: - Main music details view

struct MusicDetailsView: View {
    @ObservedObject var viewModel: EditorViewModel

    private let trackRowHeight: CGFloat = 66
    private let pixelsPerTick: CGFloat = 0.15
    private let trackLabelWidth: CGFloat = 160

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with play/stop controls
            HStack(spacing: 12) {
                Text("Music")
                    .font(.title2)
                    .fontWeight(.bold)

                if let music = viewModel.music {
                    Text("\(music.trackCount) tracks")
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                }

                Spacer()

                Button {
                    viewModel.playMusic()
                } label: {
                    Label("Play", systemImage: "play.fill")
                }
                .disabled(viewModel.isMusicPlaying)

                Button {
                    viewModel.stopMusic()
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                }
                .disabled(!viewModel.isMusicPlaying)
            }

            Divider()

            // Track list with timelines
            if let music = viewModel.music, music.trackCount > 0 {
                let timelineWidth = max(CGFloat(music.totalTicks) * pixelsPerTick, 200)

                // Column headers
                HStack(spacing: 0) {
                    Text("Track")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .frame(width: trackLabelWidth, alignment: .leading)

                    Text("Events")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 8)
                }

                ScrollView(.vertical, showsIndicators: true) {
                    HStack(alignment: .top, spacing: 0) {
                        // Left column: track controls (fixed width)
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(
                                Array(0..<music.trackCount), id: \.self
                            ) { trackIndex in
                                trackControlRow(music: music, trackIndex: trackIndex)
                            }
                        }
                        .frame(width: trackLabelWidth)

                        // Right column: timelines (horizontally scrollable, synced)
                        ScrollView(.horizontal, showsIndicators: true) {
                            VStack(alignment: .leading, spacing: 0) {
                                ForEach(
                                    Array(0..<music.trackCount), id: \.self
                                ) { trackIndex in
                                    trackTimelineRow(
                                        music: music,
                                        trackIndex: trackIndex,
                                        timelineWidth: timelineWidth
                                    )
                                }
                            }
                            .overlay(alignment: .topLeading) {
                                playheadLine(
                                    totalHeight: CGFloat(music.trackCount) * trackRowHeight
                                )
                            }
                        }
                    }
                }
            } else {
                Text("No tracks available")
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
    }

    @ViewBuilder
    private func trackControlRow(music: Music, trackIndex: Int) -> some View {
        HStack(spacing: 8) {
            Text("Track \(trackIndex)")
                .font(.system(.caption, design: .monospaced))
                .frame(width: 60, alignment: .leading)
                .help(instrumentTooltip(music: music, trackIndex: trackIndex))

            if trackIndex < viewModel.trackMuteStates.count {
                Toggle("", isOn: Binding(
                    get: { !viewModel.trackMuteStates[trackIndex] },
                    set: { _ in viewModel.toggleTrackMute(trackIndex) }
                ))
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
            }

            Text("\(music.trackEvents(at: trackIndex).count)")
                .font(.system(.caption2, design: .monospaced))
                .foregroundColor(.secondary)
        }
        .frame(width: trackLabelWidth, height: trackRowHeight, alignment: .leading)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    private func instrumentTooltip(music: Music, trackIndex: Int) -> String {
        guard let info = music.trackInstrument(at: trackIndex) else {
            return "Track \(trackIndex)\nNo instrument"
        }

        let ins = info.instrument
        let waveNames = ["Sine", "Half-Sine", "Abs-Sine", "Pulse-Sine",
                         "Sine (even)", "Abs-Sine (even)", "Square", "Derived"]

        let modWave = Int(ins.modWaveformSelect) < waveNames.count
            ? waveNames[Int(ins.modWaveformSelect)]
            : "\(ins.modWaveformSelect)"
        let carWave = Int(ins.carrierWaveformSelect) < waveNames.count
            ? waveNames[Int(ins.carrierWaveformSelect)]
            : "\(ins.carrierWaveformSelect)"

        var lines: [String] = []
        lines.append("Track \(trackIndex) — Instrument #\(info.programNumber)")
        lines.append("Voice: \(ins.voiceNumber)  Feedback: \(ins.feedback)  Connector: \(ins.connector)")
        lines.append("")
        lines.append("Modulator")
        lines.append("  Atk=\(ins.modAttack) Dcy=\(ins.modDecay) Sus=\(ins.modSustain) Rel=\(ins.modRelease)")
        lines.append("  Out=\(ins.modOutputLevel) Wave=\(modWave) Mult=\(ins.modFrequencyMultiplier)")
        lines.append("  KSL=\(ins.modKeyScalingLevel) KSR=\(ins.modKeyScalingRate)")
        lines.append("  AM=\(ins.modAmplitudeModulation) Vib=\(ins.modFrequencyVibrato)")
        lines.append("")
        lines.append("Carrier")
        lines.append("  Atk=\(ins.carrierAttack) Dcy=\(ins.carrierDecay) Sus=\(ins.carrierSustain) Rel=\(ins.carrierRelease)")
        lines.append("  Out=\(ins.carrierOutputLevel) Wave=\(carWave) Mult=\(ins.carrierFrequencyMultiplier)")
        lines.append("  KSL=\(ins.carrierKeyScalingLevel) KSR=\(ins.carrierKeyScalingRate)")
        lines.append("  AM=\(ins.carrierAmplitudeModulation) Vib=\(ins.carrierFrequencyVibrato)")

        if ins.rootNodeTranspose != 0 || ins.pitchSlideDuration != 0 {
            lines.append("")
            lines.append("HERAD Macros")
            if ins.rootNodeTranspose != 0 {
                lines.append("  Transpose: \(ins.rootNodeTranspose)")
            }
            if ins.pitchSlideDuration != 0 {
                lines.append("  Pitch Slide: range=\(ins.pitchSlideRange) dur=\(ins.pitchSlideDuration)")
            }
        }

        return lines.joined(separator: "\n")
    }

    @ViewBuilder
    private func playheadLine(totalHeight: CGFloat) -> some View {
        if viewModel.isMusicPlaying || viewModel.musicPlaybackTick > 0 {
            let playheadX = CGFloat(viewModel.musicPlaybackTick) * pixelsPerTick
            Rectangle()
                .fill(Color.red)
                .frame(width: 1.5, height: totalHeight)
                .offset(x: playheadX)
                .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private func trackTimelineRow(
        music: Music,
        trackIndex: Int,
        timelineWidth: CGFloat
    ) -> some View {
        MusicTrackTimelineView(
            events: music.trackEvents(at: trackIndex),
            maxTicks: music.totalTicks,
            pixelsPerTick: pixelsPerTick,
            isMuted: trackIndex < viewModel.trackMuteStates.count
                && viewModel.trackMuteStates[trackIndex]
        )
        .frame(width: timelineWidth, height: trackRowHeight)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }
}
