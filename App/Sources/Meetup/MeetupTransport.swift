import Foundation
import MultipeerConnectivity

/// What the transport reports. Peers are identified by an opaque key only.
enum MeetupTransportEvent: Sendable, Equatable {
    case connected(peer: String)
    case received(Data)
    case disconnected
}

/// Carries meetup messages to one nearby peer at a time.
protocol MeetupTransport: AnyObject, Sendable {
    /// A random token for this install, used to tell pairs apart for the daily limit.
    var localKey: String { get }
    var events: AsyncStream<MeetupTransportEvent> { get }
    func start()
    func stop()
    func send(_ data: Data)
}

/// MultipeerConnectivity over the local network. The peer name is a random
/// token made once per install, never the device or player name.
///
/// Advertises and browses at the same time. To avoid two crossing invitations,
/// only the side with the smaller token invites.
final class MultipeerMeetupTransport: NSObject, MeetupTransport, @unchecked Sendable {
    static let serviceType = "hingeling"
    private static let tokenKey = "meetup.peerToken"

    let localKey: String
    let events: AsyncStream<MeetupTransportEvent>
    private let continuation: AsyncStream<MeetupTransportEvent>.Continuation
    private let lock = NSLock()
    private let peerID: MCPeerID
    private let session: MCSession
    private let advertiser: MCNearbyServiceAdvertiser
    private let browser: MCNearbyServiceBrowser
    private var connectedPeer: MCPeerID?
    private var running = false

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
        advertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: nil, serviceType: Self.serviceType)
        browser = MCNearbyServiceBrowser(peer: peerID, serviceType: Self.serviceType)
        let (stream, streamContinuation) = AsyncStream.makeStream(of: MeetupTransportEvent.self, bufferingPolicy: .bufferingNewest(32))
        events = stream
        continuation = streamContinuation
        super.init()
        session.delegate = self
        advertiser.delegate = self
        browser.delegate = self
    }

    deinit {
        continuation.finish()
    }

    func start() {
        let shouldStart: Bool = lock.withLock {
            defer { running = true }
            return !running
        }
        guard shouldStart else { return }
        advertiser.startAdvertisingPeer()
        browser.startBrowsingForPeers()
    }

    func stop() {
        let wasRunning: Bool = lock.withLock {
            defer { running = false; connectedPeer = nil }
            return running
        }
        guard wasRunning else { return }
        advertiser.stopAdvertisingPeer()
        browser.stopBrowsingForPeers()
        session.disconnect()
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
                // One meetup at a time.
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
        let free = lock.withLock { running && connectedPeer == nil }
        guard free, localKey < peerID.displayName else { return }
        browser.invitePeer(peerID, to: session, withContext: nil, timeout: 15)
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {}
}
