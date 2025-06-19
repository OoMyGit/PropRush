//
//  MultipeerManager.swift.swift
//  Prop Call
//
//  Created by Kwandy Chandra on 19/06/25.
//
//  Prop Call Multiplayer

import Foundation
import MultipeerConnectivity

class MultipeerManager: NSObject, ObservableObject {
    private let serviceType = "propcallgame" // ✅ Same on all devices
    private let peerID = MCPeerID(displayName: UIDevice.current.name)
    private var session: MCSession!
    private var advertiser: MCNearbyServiceAdvertiser!
    private var browser: MCNearbyServiceBrowser!

    @Published var peerScores: [String: Int] = [:]
    @Published var receivedChallenge: String = ""
    @Published var username: String = ""

    override init() {
        super.init()

        session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self

        advertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: nil, serviceType: serviceType)
        advertiser.delegate = self
        advertiser.startAdvertisingPeer()

        browser = MCNearbyServiceBrowser(peer: peerID, serviceType: serviceType)
        browser.delegate = self
        browser.startBrowsingForPeers()

        peerScores[peerID.displayName] = 0
        print("🟢 Multipeer ready: \(peerID.displayName)")
    }

    func sendScore(_ score: Int) {
        peerScores[username] = score
        let payload = ["player": username, "score": "\(score)"]
        sendToPeers(payload)
    }

    func sendChallenge(word: String) {
        let payload = ["challenge": word]
        sendToPeers(payload)
    }

    func setUsername(_ name: String) {
        self.username = name
        peerScores[name] = 0
    }

    private func sendToPeers(_ payload: [String: String]) {
        guard !session.connectedPeers.isEmpty else {
            print("⚠️ No peers connected")
            return
        }

        if let data = try? JSONEncoder().encode(payload) {
            do {
                try session.send(data, toPeers: session.connectedPeers, with: .reliable)
                print("📤 Sent: \(payload)")
            } catch {
                print("❌ Send error: \(error)")
            }
        }
    }
}

extension MultipeerManager: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        switch state {
        case .connected:
            print("✅ Connected to peer: \(peerID.displayName)")
        case .connecting:
            print("🔄 Connecting to peer: \(peerID.displayName)")
        case .notConnected:
            print("❌ Disconnected from peer: \(peerID.displayName)")
        @unknown default:
            break
        }
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        do {
            let dict = try JSONDecoder().decode([String: String].self, from: data)

            if let player = dict["player"], let scoreStr = dict["score"], let score = Int(scoreStr) {
                DispatchQueue.main.async {
                    self.peerScores[player] = score
                }
            }

            if let challenge = dict["challenge"] {
                DispatchQueue.main.async {
                    self.receivedChallenge = challenge
                }
            }
        } catch {
            print("❌ JSON decode failed: \(error)")
        }
    }
    


    func session(_: MCSession, didReceive: InputStream, withName: String, fromPeer: MCPeerID) {}
    func session(_: MCSession, didStartReceivingResourceWithName: String, fromPeer: MCPeerID, with: Progress) {}
    func session(_: MCSession, didFinishReceivingResourceWithName: String, fromPeer: MCPeerID, at: URL?, withError: Error?) {}
}

extension MultipeerManager: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID,
                    withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        print("📩 Received invitation from: \(peerID.displayName)")
        invitationHandler(true, session)
    }
}

extension MultipeerManager: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        print("🔍 Found peer: \(peerID.displayName), sending invite")
        browser.invitePeer(peerID, to: session, withContext: nil, timeout: 10)
    }

    func browser(_: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {}
}
