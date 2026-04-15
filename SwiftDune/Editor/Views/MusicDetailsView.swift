//
//  MusicDetailsView.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 06/02/2026.
//

import Foundation
import SwiftUI

// MARK: - Note span model

struct MusicNoteSpan {
    var startTick: UInt32
    var endTick: UInt32
    var noteNumber: UInt8
    var velocity: UInt8
}

// MARK: - Piano keyboard view (fixed left column)

private struct PianoKeyboardView: View {
    let minNote: Int
    let maxNote: Int
    let noteRowHeight: CGFloat
    let width: CGFloat

    private static let blackKeyIndices: Set<Int> = [1, 3, 6, 8, 10]

    var body: some View {
        Canvas { context, size in
            let totalNotes = maxNote - minNote + 1
            var noteIdx = maxNote

            while noteIdx >= minNote {
                let rowIndex = maxNote - noteIdx
                let posY = CGFloat(rowIndex) * noteRowHeight
                let semitone = noteIdx % 12
                let isBlack = PianoKeyboardView.blackKeyIndices.contains(semitone)

                let keyRect = CGRect(x: 0, y: posY, width: size.width, height: noteRowHeight)
                let keyColor: Color = isBlack ? Color(white: 0.18) : Color.white
                context.fill(Path(keyRect), with: .color(keyColor))

                var divider = Path()
                divider.move(to: CGPoint(x: 0, y: posY + noteRowHeight - 0.5))
                divider.addLine(to: CGPoint(x: size.width, y: posY + noteRowHeight - 0.5))
                context.stroke(divider, with: .color(Color(white: 0.55)), lineWidth: 0.5)

                if semitone == 0 {
                    let octave = noteIdx / 12 - 1
                    let label = "C\(octave)"
                    let text = context.resolve(
                        Text(label)
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundColor(Color(white: 0.35))
                    )
                    context.draw(text, at: CGPoint(x: size.width - 5, y: posY + noteRowHeight / 2), anchor: .trailing)
                }

                noteIdx -= 1
            }

            // Right border separator
            var border = Path()
            border.move(to: CGPoint(x: size.width - 0.5, y: 0))
            border.addLine(to: CGPoint(x: size.width - 0.5, y: CGFloat(totalNotes) * noteRowHeight))
            context.stroke(border, with: .color(Color(white: 0.4)), lineWidth: 1)
        }
        .frame(width: width, height: CGFloat(maxNote - minNote + 1) * noteRowHeight)
    }
}

// MARK: - Piano roll view (scrollable timeline)

private struct PianoRollView: View {
    let noteSpans: [MusicNoteSpan]
    let minNote: Int
    let maxNote: Int
    let noteRowHeight: CGFloat
    let pixelsPerTick: CGFloat
    let isMuted: Bool

    private static let blackKeyIndices: Set<Int> = [1, 3, 6, 8, 10]

    var body: some View {
        Canvas { context, size in
            // Row backgrounds
            var noteIdx = maxNote
            while noteIdx >= minNote {
                let rowIndex = maxNote - noteIdx
                let rowPosY = CGFloat(rowIndex) * noteRowHeight
                let semitone = noteIdx % 12
                let isBlack = PianoRollView.blackKeyIndices.contains(semitone)

                let bgColor: Color = isBlack ? Color(white: 0.13) : Color(white: 0.18)
                context.fill(
                    Path(CGRect(x: 0, y: rowPosY, width: size.width, height: noteRowHeight)),
                    with: .color(bgColor)
                )

                var divider = Path()
                divider.move(to: CGPoint(x: 0, y: rowPosY + noteRowHeight - 0.5))
                divider.addLine(to: CGPoint(x: size.width, y: rowPosY + noteRowHeight - 0.5))
                context.stroke(divider, with: .color(Color(white: 0.25)), lineWidth: 0.5)

                noteIdx -= 1
            }

            // Note bars
            let notePad: CGFloat = 1.5
            var spanIdx = 0
            while spanIdx < noteSpans.count {
                let span = noteSpans[spanIdx]
                let note = Int(span.noteNumber)

                if note >= minNote && note <= maxNote {
                    let rowIndex = maxNote - note
                    let posX = CGFloat(span.startTick) * pixelsPerTick
                    let barWidth = max(CGFloat(span.endTick - span.startTick) * pixelsPerTick, 2.5)
                    let posY = CGFloat(rowIndex) * noteRowHeight + notePad
                    let barHeight = noteRowHeight - notePad * 2

                    let hue = Double(note % 12) / 12.0
                    let color: Color = isMuted
                        ? Color(white: 0.45)
                        : Color(hue: hue, saturation: 0.75, brightness: 0.92)

                    context.fill(
                        Path(roundedRect: CGRect(x: posX, y: posY, width: barWidth, height: barHeight), cornerRadius: 2),
                        with: .color(color)
                    )
                }

                spanIdx += 1
            }
        }
    }
}

// MARK: - Note span helpers

enum MusicNoteSpanHelper {
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

    private let noteRowHeight: CGFloat = 14
    private let pianoWidth: CGFloat = 52
    private let pixelsPerTick: CGFloat = 0.15

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerView
            Divider()
            trackContent
            Spacer(minLength: 0)
        }
        .padding()
    }

    @ViewBuilder
    private var trackContent: some View {
        if let music = viewModel.music, music.trackCount > 0 {
            let trackIndex = min(viewModel.selectedTrackIndex, music.trackCount - 1)
            trackInfoBar(music: music, trackIndex: trackIndex)
            pianoRollContent(music: music, trackIndex: trackIndex)
        } else {
            Text("No track selected")
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private func pianoRollContent(music: Music, trackIndex: Int) -> some View {
        let events = music.trackEvents(at: trackIndex)
        let noteSpans = MusicNoteSpanHelper.computeNoteSpans(from: events, maxTicks: music.totalTicks)
        let (rawMin, rawMax) = MusicNoteSpanHelper.computeNoteRange(from: noteSpans)
        let minNote = max(0, rawMin - 2)
        let maxNote = min(127, rawMax + 2)
        let totalHeight = CGFloat(maxNote - minNote + 1) * noteRowHeight
        let timelineWidth = max(CGFloat(music.totalTicks) * pixelsPerTick, 400)

        ScrollView(.vertical, showsIndicators: true) {
            HStack(alignment: .top, spacing: 0) {
                PianoKeyboardView(
                    minNote: minNote,
                    maxNote: maxNote,
                    noteRowHeight: noteRowHeight,
                    width: pianoWidth
                )

                ScrollView(.horizontal, showsIndicators: true) {
                    PianoRollView(
                        noteSpans: noteSpans,
                        minNote: minNote,
                        maxNote: maxNote,
                        noteRowHeight: noteRowHeight,
                        pixelsPerTick: pixelsPerTick,
                        isMuted: trackIndex < viewModel.trackMuteStates.count
                            && viewModel.trackMuteStates[trackIndex]
                    )
                    .frame(width: timelineWidth, height: totalHeight)
                    .overlay(alignment: .topLeading) {
                        playheadLine(totalHeight: totalHeight)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var headerView: some View {
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
    }

    @ViewBuilder
    private func trackInfoBar(music: Music, trackIndex: Int) -> some View {
        HStack(spacing: 16) {
            Text("Track \(trackIndex)")
                .font(.system(.headline, design: .monospaced))

            Text("\(music.trackEvents(at: trackIndex).count) events")
                .font(.subheadline)
                .foregroundColor(.secondary)

            if let info = music.trackInstrument(at: trackIndex) {
                Text("Instrument #\(info.programNumber)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if trackIndex < viewModel.trackMuteStates.count {
                Toggle(viewModel.trackMuteStates[trackIndex] ? "Muted" : "Active", isOn: Binding(
                    get: { !viewModel.trackMuteStates[trackIndex] },
                    set: { _ in viewModel.toggleTrackMute(trackIndex) }
                ))
                .toggleStyle(.switch)
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 2)
    }

    @ViewBuilder
    private func playheadLine(totalHeight: CGFloat) -> some View {
        if viewModel.isMusicPlaying || viewModel.musicPlaybackTick > 0 {
            let playheadX = CGFloat(viewModel.musicPlaybackTick) * pixelsPerTick
            Rectangle()
                .fill(Color.red.opacity(0.85))
                .frame(width: 1.5, height: totalHeight)
                .offset(x: playheadX)
                .allowsHitTesting(false)
        }
    }
}
