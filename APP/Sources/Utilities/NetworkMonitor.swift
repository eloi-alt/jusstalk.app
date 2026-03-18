import Foundation
import Network

final class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()

    @Published private(set) var isConnected: Bool = false
    @Published private(set) var connectionType: NWInterface.InterfaceType?

    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.jusstalk.networkmonitor")

    private init() {
        startMonitoring()
    }

    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                await MainActor.run {
                    self?.isConnected = path.status == .satisfied
                    self?.connectionType = path.availableInterfaces.first?.type
                }
            }
        }
        monitor.start(queue: monitorQueue)
    }

    func stopMonitoring() {
        monitor.cancel()
    }

    static var connectionDescription: String {
        guard shared.isConnected else { return "No internet connection" }

        switch shared.connectionType {
        case .wifi: return "Wi-Fi"
        case .cellular: return "Cellular"
        case .wiredEthernet: return "Ethernet"
        default: return "Internet"
        }
    }
}
