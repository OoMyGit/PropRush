//
//  GameRoundManager.swift
//  Prop Call
//
//  Created by Alfred Hans Witono on 19/06/25.
//

import Foundation
import SwiftUI

class GameRoundManager: ObservableObject {
    @Published var currentLetter: String = ""
    @Published var timeRemaining: Int = 30
    @Published var score: Int = 0
    @Published var roundEnded: Bool = false
    @Published var round: Int = 1
    @Published var gameOver: Bool = false

    private var timer: Timer?
    private let maxRounds: Int = 5
    private let validLetters: [String] = "ABCDEFGHIKLMNOPRSTUVWY".map { String($0) }

    func startGame() {
        score = 0
        round = 1
        gameOver = false
        startNewRound()
    }

    func startNewRound() {
        if round > maxRounds {
            gameOver = true
            stop()
            return
        }

        roundEnded = false
        currentLetter = validLetters.randomElement() ?? "B"
        timeRemaining = 30
        startTimer()
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            if self.timeRemaining > 0 {
                self.timeRemaining -= 1
            } else {
                self.handleNoMatchAndContinue()
            }
        }
    }

    private func handleNoMatchAndContinue() {
        endRound()
        round += 1
        startNewRound()
    }

    func endRound() {
        timer?.invalidate()
        roundEnded = true
    }

    func incrementScoreAndNextRound(onSuccess: (() -> Void)? = nil) {
        score += 1
        round += 1
        startNewRound()
        onSuccess?()
    }

    func stop() {
        timer?.invalidate()
    }

    func promptText() -> String {
        "Find something starting with: \"\(currentLetter)\""
    }
}
