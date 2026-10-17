import Foundation
import MultipeerConnectivity
import PocketPetCore

/// What the transport reports. Peers are identified by an opaque key only.
enum MeetupTransportEvent: Sendable, Equatable {
    /// A pet nearby is advertising. `card` is what it chose to show while looking.
    case found(peer: String, card: PetCard?)
    case lost(peer: String)
    case connected(peer: String)
    case received(Data)
    case disconnected
}

/// Carries meetup messages to one nearby peer at a time.
protocol MeetupTransport: AnyObject, Sendable {
    /// A random token for this install, used to tell pairs apart for the daily limits.
    var localKey: String { get }
    var events: AsyncStream<MeetupTransportEvent> { get }
    /// Starts advertising `card` and looking for other pets. With `autoInvite`
    /// on, the first pet found is invited straight away (two half-folded Duos).
    func start(advertising card: PetCard, autoInvite: Bool)
    func stop()
    /// Invites a pet from the nearby list.
    func invite(peer: String)
    func send(_ data: Data)
}

/// MultipeerConnectivity over the local network: the same Wi-Fi, peer-to-peer
/// Wi-Fi or Bluetooth, whichever the phones can reach. The peer name is a
/// random token made once per install, never the device or player name.
///
/// While looking, it advertises the pet's name, life stage and mood so others
/// can pick it from a list. Invitations are accepted while meetups are on and
/// no other pet is visiting.
final class MultipeerMeetupTransport: NSObject, MeetupTransport, @unchecked Sendable {
    static let serviceType = "hingeling"
    private static let tokenKey = "meetup.peerToken"

    let localKey: String
    let events: AsyncStream<MeetupTransportEvent>
    private let continuation: AsyncStream<MeetupTransportEvent>.Continuation
    private let lock = NSLock()
    private let peerID: MCPeerID
    private let session: MCSession
    private let browser: MCNearbyServiceBrowser
    private var advertiser: MCNearbyServiceAdvertiser?
    private var found: [String: MCPeerID] = [:]
    private var connectedPeer: MCPeerID?
    private var running = false
    private var autoInvite = false

    init(defaults: UserDefaults = .standard) {
        let token: String
        if let saved = defaults.string(forKey: Self.tokenKey) {
            token = saved
        } else {
            token = String(UUID().uuidString.prefix(12))
            defaults.set(token, forKey: Self.tokenKey)
        }
        localKey = token
        peerID = MCPeerID(displayName: token)
        session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        browser = MCNearbyServiceBrowser(peer: peerID, serviceType: Self.serviceType)
        let (stream, streamContinuation) = AsyncStream.makeStream(of: MeetupTransportEvent.self, bufferingPolicy: .bufferingNewest(64))
        events = stream
        continuation = streamContinuation
        super.init()
        session.delegate = self
        browser.delegate = self
    }

    deinit {
        continuation.finish()
    }

    /// What other phones see while looking: only the pet's name, stage and mood.
    static func discoveryInfo(for card: PetCard) -> [String: String] {
        ["n": String(card.name.prefix(20)), "s": card.stage.rawValue, "m": card.mood.rawValue]
    }

    static func card(from info: [String: String]?) -> PetCard? {
        guard let info, let name = info["n"], let stage = info["s"].flatMap(LifeStage.init(rawValue:)), let mood = info["m"].flatMap(Mood.init(rawValue:)) else { return nil }
        return PetCard(name: name, stage: stage, mood: mood)
    }

    func start(advertising card: PetCard, autoInvite: Bool) {
        let advertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: Self.discoveryInfo(for: card), serviceType: Self.serviceType)
        advertiser.delegate = self
        let (old, wasRunning): (MCNearbyServiceAdvertiser?, Bool) = lock.withLock {
            defer {
                self.advertiser = advertiser
                self.autoInvite = autoInvite
                running = true
            }
            return (self.advertiser, running)
        }
        old?.stopAdvertisingPeer()
        advertiser.startAdvertisingPeer()
        if !wasRunning { browser.startBrowsingForPeers() }
    }

    func stop() {
        let (advertiser, wasRunning): (MCNearbyServiceAdvertiser?, Bool) = lock.withLock {
            defer {
                running = false
                connectedPeer = nil
                found = [:]
                self.advertiser = nil
            }
            return (self.advertiser, running)
        }
        guard wasRunning else { return }
        advertiser?.stopAdvertisingPeer()
        browser.stopBrowsingForPeers()
        session.disconnect()
    }

    func invite(peer: String) {
        let target: MCPeerID? = lock.withLock { running && connectedPeer == nil ? found[peer] : nil }
        guard let target else { return }
        browser.invitePeer(target, to: session, withContext: nil, timeout: 15)
    }

    func send(_ data: Data) {
        guard let peer = lock.withLock({ connectedPeer }) else { return }
        try? session.send(data, toPeers: [peer], with: .reliable)
    }
}

extension MultipeerMeetupTransport: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        switch state {
        case .connected:
            let isFirst: Bool = lock.withLock {
                guard connectedPeer == nil else { return false }
                connectedPeer = peerID
                return true
            }
            if isFirst {
                continuation.yield(.connected(peer: peerID.displayName))
            } else {
                // One visitor at a time.
                session.cancelConnectPeer(peerID)
            }
        case .notConnected:
            let wasOurs: Bool = lock.withLock {
                guard connectedPeer == peerID else { return false }
                connectedPeer = nil
                return true
            }
            if wasOurs { continuation.yield(.disconnected) }
        default:
            break
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        guard lock.withLock({ connectedPeer == peerID }) else { return }
        continuation.yield(.received(data))
    }

    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        stream.close()
    }

    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        progress.cancel()
    }

    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: (any Error)?) {}
}

extension MultipeerMeetupTransport: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        let free = lock.withLock { running && connectedPeer == nil }
        invitationHandler(free, free ? session : nil)
    }
}

extension MultipeerMeetupTransport: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        let shouldInvite: Bool = lock.withLock {
            found[peerID.displayName] = peerID
            // Only the side with the smaller token invites, so two auto-inviting
            // phones don't cross invitations.
            return running && autoInvite && connectedPeer == nil && localKey < peerID.displayName
        }
        continuation.yield(.found(peer: peerID.displayName, card: Self.card(from: info)))
        if shouldInvite { browser.invitePeer(peerID, to: session, withContext: nil, timeout: 15) }
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        _ = lock.withLock { found.removeValue(forKey: peerID.displayName) }
        continuation.yield(.lost(peer: peerID.displayName))
    }
}
