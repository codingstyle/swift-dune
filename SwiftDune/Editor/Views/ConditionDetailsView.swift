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
              let cond = condition.expressions[index]
              
              Text(cond.debugDescription)
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
