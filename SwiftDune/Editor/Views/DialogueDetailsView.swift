//
//  DialogueDetailsView.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 31/10/2026.
//

import Foundation
import SwiftUI

struct DialogueDetailsView: View {
  @ObservedObject var viewModel: EditorViewModel
  
  var body: some View {
    VStack(alignment: .leading) {
      Text("Dialogue")
        .font(.title2)
        .fontWeight(.bold)
      
      if let dialogue = viewModel.dialogue {
        ScrollView {
          LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(sections(in: dialogue)) { section in
              Text(section.title)
                .fontWeight(.semibold)
                .padding(.top, 8)
              
              ForEach(Array(section.lines.enumerated()), id: \.offset) { _, line in
                Text(line)
                  .fontDesign(.monospaced)
                  .padding(.bottom, 5)
              }
            }
          }
        }
      }
      
      Spacer()
    }
    .padding()
  }
  
  
  private func sections(in dialogue: Dialogue) -> [DialogueSection] {
    var sections: [DialogueSection] = []
    var slot = 0
    while slot < dialogue.records.count {
      let record = dialogue.records[slot]
      if !record.isEmpty {
        let lines = record.sentences.map { sentence in
          ConditionText.condition(sentence.conditionId, in: viewModel.condition)
        }
        sections.append(DialogueSection(slot: slot, title: title(for: slot), lines: lines))
      }
      slot += 1
    }
    return sections
  }
  
  
  private func title(for slot: Int) -> String {
    let person = UInt8(truncatingIfNeeded: slot >> 3)
    let topic = UInt16(slot & 7)
    return "\(speakerName(person)) • \(topicName(topic))"
  }
  
  
  private func speakerName(_ person: UInt8) -> String {
    switch DialogueSpeaker(rawValue: person) {
    case .leto:
      return "Leto"
    case .jessica:
      return "Jessica"
    case .thufir:
      return "Thufir"
    case .duncan:
      return "Duncan"
    case .gurney:
      return "Gurney"
    case .stilgar:
      return "Stilgar"
    case .kynes:
      return "Kynes"
    case .chani:
      return "Chani"
    case .harah:
      return "Harah"
    case .baron:
      return "Baron"
    case .feyd:
      return "Feyd"
    case .emperor:
      return "Emperor"
    case .harkonnenCaptain:
      return "Harkonnen captain"
    case .smugglers:
      return "Smugglers"
    case .fremen1:
      return "Fremen 1"
    case .fremen2:
      return "Fremen 2"
    case .narrator:
      return "Narrator"
    case .none:
      return String(format: "Person %02X", person)
    }
  }
  
  
  private func topicName(_ topic: UInt16) -> String {
    switch DialogueTopic(rawValue: topic) {
    case .talk0:
      return "Talk 0"
    case .talk1:
      return "Talk 1"
    case .talk2:
      return "Talk 2"
    case .talk3:
      return "Talk 3"
    case .auto:
      return "Auto"
    case .comeWithMe:
      return "Come with me"
    case .stayHere:
      return "Stay here"
    case .extra:
      return "Extra"
    case .none:
      return String(format: "Topic %X", topic)
    }
  }
}


private struct DialogueSection: Identifiable {
  let slot: Int
  let title: String
  let lines: [String]
  
  var id: Int { slot }
}
