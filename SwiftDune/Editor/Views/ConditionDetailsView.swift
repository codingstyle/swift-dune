//
//  ConditionDetailsView.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 15/09/2026.
//

import Foundation
import SwiftUI

struct ConditionDetailsView: View {
  @ObservedObject var viewModel: EditorViewModel
  
  var body: some View {
    VStack(alignment: .leading) {
      Text("Condit")
        .font(.title2)
        .fontWeight(.bold)
      
      if let condition = viewModel.condition {
        ScrollView {
          VStack(alignment: .leading) {
            ForEach(0..<condition.expressions.count, id: \.self) { index in
              Text(ConditionText.expression(condition.expressions[index]))
                .fontDesign(.monospaced)
                .padding(.bottom, 5)
            }
          }
        }
      }
      
      Spacer()
    }
    .padding()
  }
}


@MainActor
enum ConditionText {
  static func expression(_ expression: ConditionExpression) -> String {
    return expression.tokens.map { token in
      switch token {
      case .operation(let operation):
        return operation.debugDescription
      case .operand(let operand):
        return operandText(operand)
      }
    }.joined(separator: " ")
  }
  
  
  static func condition(_ conditionId: UInt16, in condition: Condition?) -> String {
    let label = String(format: "%04X", conditionId)
    if conditionId == 0 {
      return "\(label) • condition 0"
    }
    guard let condition, Int(conditionId) <= condition.expressions.count else {
      return label
    }
    let text = expression(condition.expressions[Int(conditionId) - 1])
    if text.isEmpty {
      return label
    }
    return "\(label) • \(text)"
  }
  
  
  private static func operandText(_ operand: ConditionOperand) -> String {
    switch operand {
    case .variable(let isWord, let dsOffset):
      let width = isWord ? "u16" : "u8"
      let name = GameState.shared.segmentVariableName(UInt16(dsOffset))
      if name.isEmpty {
        return "\(width)@\(String(format: "%04X", dsOffset))"
      }
      return "\(width) \(name)"
    case .immediate8(let value):
      return String(format: "%02X", value)
    case .immediate16(let value):
      return String(format: "%04X", value)
    }
  }
}
