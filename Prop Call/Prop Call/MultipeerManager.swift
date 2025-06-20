//
//  MultipeerManager.swift
//  Prop Call
//
//  Created by Alfred Hans Witono on 04/06/25.
//

//  MultipeerManager.swift
//  Prop Call
//
//  Created by Alfred Hans Witono on 04/06/25.

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
    @Published var peerDisplayNames: [MCPeerID: String] = [:]
    var receivedGameStatePublisher = PassthroughSubject<GameState, Never>()

    private var username: String = ""

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

    func sendHostName(_ name: String) {
        let dict: [String: Any] = ["type": "host", "host": name]
        if let data = try? JSONSerialization.data(withJSONObject: dict, options: []) {
            sendDataToAllPeers(data)
        }
    }
    
    func setUsername(_ name: String) {
        username = name
        peerScores[name] = 0
        
        if hostName == nil {
            hostName = name
            sendHostName(name)
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

    private func sendDataToAllPeers(_ data: Data) {
        guard !session.connectedPeers.isEmpty else { return }
        do {
            try session.send(data, toPeers: session.connectedPeers, with: .reliable)
        } catch {
            print("Send error: \(error.localizedDescription)")
        }
    }
}

extension MultipeerManager: MCSessionDelegate, MCNearbyServiceAdvertiserDelegate, MCNearbyServiceBrowserDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        print("Peer \(peerID.displayName) changed state: \(state.rawValue)")
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        if let wrapper = try? JSONDecoder().decode(GameStateWrapper.self, from: data),
           wrapper.type == "gamestate" {
            DispatchQueue.main.async {
                self.receivedGameStatePublisher.send(wrapper.state)
            }
        } else if let dict = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                  let type = dict["type"] as? String {

            switch type {
            case "score":
                if let name = dict["name"] as? String,
                   let score = dict["score"] as? Int {
                    DispatchQueue.main.async {
                        self.peerScores[name] = score
                    }
                }

            case "username":
                if let username = dict["username"] as? String {
                    DispatchQueue.main.async {
                        self.peerDisplayNames[peerID] = username
                    }
                }

            case "host":
                if let host = dict["host"] as? String {
                    DispatchQueue.main.async {
                        self.hostName = host
                    }
                }

            default:
                break
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

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {}
}
