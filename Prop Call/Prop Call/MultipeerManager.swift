//
//  MultipeerManager.swift
//  Prop Call
//
//  Created by Kwandy Chandra on 19/06/25.
//

import Foundation
import MultipeerConnectivity
import Combine

struct GameState: Codable {
    let round: Int
    let score: Int
    let currentLetter: String
    let timeRemaining: Int
}

struct GameStateWrapper: Codable {
    let type: String
    let state: GameState
}

class MultipeerManager: NSObject, ObservableObject {
    private let serviceType = "propcallgame"
    private let myPeerID = MCPeerID(displayName: UIDevice.current.name)
    
    private var session: MCSession!
    private var advertiser: MCNearbyServiceAdvertiser!
    private var browser: MCNearbyServiceBrowser!
    
    @Published var peerScores: [String: Int] = [:]
    @Published var hostName: String? = nil
    
    // Publishers to signal events to the UI
    var receivedGameStatePublisher = PassthroughSubject<GameState, Never>()
    var gameShouldStartPublisher = PassthroughSubject<Void, Never>()

    private(set) var username: String = ""
    
    override init() {
        super.init()
        
        session = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self
        
        advertiser = MCNearbyServiceAdvertiser(peer: myPeerID, discoveryInfo: nil, serviceType: serviceType)
        advertiser.delegate = self
        advertiser.startAdvertisingPeer()
        
        browser = MCNearbyServiceBrowser(peer: myPeerID, serviceType: serviceType)
        browser.delegate = self
        browser.startBrowsingForPeers()
    }
    
    // MARK: - Outgoing Data Senders

    /// Called when the user sets their name and joins the lobby.
    func configureUsername(_ name: String) {
        self.username = name
        // Add self to the list immediately for instant UI feedback
        self.peerScores[name] = 0

        // If there's no host, this player becomes the host
        if self.hostName == nil {
            self.hostName = name
            sendHostName(name)
        }
        // Announce this user's arrival to all other players
//        sendUsernameAnnouncement(name)
    }

    /// Sends a command that tells all devices to start the game.
    func sendStartGameCommand() {
        // Only the host can start the game
        guard username == hostName else { return }
        let command: [String: Any] = ["type": "startGame"]
        if let data = try? JSONSerialization.data(withJSONObject: command, options: []) {
            sendDataToAllPeers(data)
        }
    }

    func sendScore(_ score: Int) {
        guard !username.isEmpty else { return }
        peerScores[username] = score
        let dict: [String: Any] = ["type": "score", "name": username, "score": score]
        if let data = try? JSONSerialization.data(withJSONObject: dict, options: []) {
            sendDataToAllPeers(data)
        }
    }
    
    func sendGameState(round: Int, score: Int, currentLetter: String, timeRemaining: Int) {
        let gameState = GameState(round: round, score: score, currentLetter: currentLetter, timeRemaining: timeRemaining)
        let wrapper = GameStateWrapper(type: "gamestate", state: gameState)
        if let data = try? JSONEncoder().encode(wrapper) {
            sendDataToAllPeers(data)
        }
    }
    
    /// Announces the host's name to the network.
    private func sendHostName(_ name: String) {
        let dict: [String: Any] = ["type": "host", "host": name]
        if let data = try? JSONSerialization.data(withJSONObject: dict, options: []) {
            sendDataToAllPeers(data)
        }
    }

    /// Announces that a new user has joined the lobby.
    private func sendUsernameAnnouncement(_ name: String) {
        let message: [String: Any] = ["type": "username", "username": name]
        if let data = try? JSONSerialization.data(withJSONObject: message) {
            sendDataToAllPeers(data)
        }
    }
    
    private func sendDataToAllPeers(_ data: Data) {
        guard !session.connectedPeers.isEmpty else { return }
        do {
            try session.send(data, toPeers: session.connectedPeers, with: .reliable)
        } catch {
            print("Send error: \(error.localizedDescription)")
        }
    }
    
    private func sendFullPeerScores(to peer: MCPeerID) {
        for (name, score) in peerScores {
            let dict: [String: Any] = [
                "type": "score",
                "name": name,
                "score": score
            ]
            if let data = try? JSONSerialization.data(withJSONObject: dict) {
                try? session.send(data, toPeers: [peer], with: .reliable)
            }
        }
    }
    
    func sendFullPlayerList() {
        let dict: [String: Any] = [
            "type": "players",
            "players": Array(peerScores.keys)
        ]
        if let data = try? JSONSerialization.data(withJSONObject: dict) {
            sendDataToAllPeers(data)
        }
    }
    
    func sendGameOver(winner: String) {
        let dict: [String: Any] = [
            "type": "gameOver",
            "winner": winner
        ]
        if let data = try? JSONSerialization.data(withJSONObject: dict) {
            sendDataToAllPeers(data)
        }
    }
    
}

// MARK: - Multipeer Delegate Methods
extension MultipeerManager: MCSessionDelegate, MCNearbyServiceAdvertiserDelegate, MCNearbyServiceBrowserDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        print("Peer \(peerID.displayName) changed state: \(state.rawValue)")

        if state == .connected {
            if let host = hostName {
                sendHostName(host)
            }

            if !username.isEmpty {
                sendUsernameAnnouncement(username)
            }

            // Send host's full state to new peer
            sendFullPeerScores(to: peerID)
            
            // 🔥 Host sends full player list to all
            if username == hostName {
                sendFullPlayerList()
            }
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        // First, try to decode as a GameState object
        if let wrapper = try? JSONDecoder().decode(GameStateWrapper.self, from: data),
           wrapper.type == "gamestate" {
            DispatchQueue.main.async {
                self.receivedGameStatePublisher.send(wrapper.state)
            }
        // If not, decode as a generic dictionary for other commands
        } else if let dict = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                  let type = dict["type"] as? String {
            
            DispatchQueue.main.async {
                switch type {
                case "score":
                    if let name = dict["name"] as? String, let score = dict["score"] as? Int {
                        self.peerScores[name] = score
                    }
                    
                case "username":
                    // A new user has announced their arrival
                    if let name = dict["username"] as? String {
                        // Add the new player to the scores dictionary if they're not already there
                        if self.peerScores[name] == nil {
                            self.peerScores[name] = 0
                        }
                    }
                    
                case "host":
                    // The host has been announced
                    if let host = dict["host"] as? String {
                        self.hostName = host
                    }
                
                case "players":
                    if let playerList = dict["players"] as? [String] {
                        for player in playerList {
                            if self.peerScores[player] == nil {
                                self.peerScores[player] = 0
                            }
                        }
                    }
                    
                case "startGame":
                    // The host has started the game
                    self.gameShouldStartPublisher.send()
                    
                case "gameOver":
                    if let win = dict["winner"] as? String {
                        DispatchQueue.main.async {
                            self.peerScores[win, default: 0] += 0 // No-op to ensure they’re in list
                            NotificationCenter.default.post(name: .gameDidEnd, object: win)
                        }
                    }
                    
                default:
                    break
                }
            }
        }
    }
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
    
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        invitationHandler(true, session)
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        browser.invitePeer(peerID, to: session, withContext: nil, timeout: 10)
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        // Optional: Handle player disconnection by removing them from the list
    }
}
