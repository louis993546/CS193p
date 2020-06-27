//
//  CS193pApp.swift
//  CS193p
//
//  Created by Louis Tsai on 6/27/20.
//

import SwiftUI

@main
struct CS193pApp: App {
    let game = EmojiMemoryGame()
    
    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: game)
        }
    }
}
