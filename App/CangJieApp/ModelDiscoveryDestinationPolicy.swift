#if canImport(Darwin)
import Darwin
#endif
import Foundation

enum ModelDiscoveryResolvedAddress: Hashable, Sendable {
    case ipv4(UInt8, UInt8, UInt8, UInt8)
    case ipv6([UInt8])

    var isPublic: Bool {
        switch self {
        case let .ipv4(first, second, third, _):
            return Self.isPublicIPv4(first, second, third)
        case let .ipv6(bytes):
            return Self.isPublicIPv6(bytes)
        }
    }

    private static func isPublicIPv4(
        _ first: UInt8,
        _ second: UInt8,
        _ third: UInt8
    ) -> Bool {
        switch first {
        case 0, 10, 127:
            return false
        case 100 where (64...127).contains(second):
            return false
        case 169 where second == 254:
            return false
        case 172 where (16...31).contains(second):
            return false
        case 192 where second == 0:
            return false
        case 192 where second == 88 && third == 99:
            return false
        case 192 where second == 168:
            return false
        case 198 where second == 18 || second == 19:
            return false
        case 198 where second == 51 && third == 100:
            return false
        case 203 where second == 0 && third == 113:
            return false
        case 224...255:
            return false
        default:
            return true
        }
    }

    private static func isPublicIPv6(_ bytes: [UInt8]) -> Bool {
        guard bytes.count == 16 else {
            return false
        }
        if bytes.prefix(10).allSatisfy({ $0 == 0 }),
           bytes[10] == 0xFF,
           bytes[11] == 0xFF {
            return isPublicIPv4(bytes[12], bytes[13], bytes[14])
        }
        guard bytes[0] & 0xE0 == 0x20 else {
            return false
        }

        let firstGroup = UInt16(bytes[0]) << 8 | UInt16(bytes[1])
        let secondGroup = UInt16(bytes[2]) << 8 | UInt16(bytes[3])
        if firstGroup == 0x2002
            || (firstGroup == 0x3FFF && secondGroup & 0xF000 == 0) {
            return false
        }
        if firstGroup == 0x2001 {
            switch secondGroup {
            case 0x0000...0x01FF, 0x0DB8:
                return false
            default:
                break
            }
        }
        return true
    }
}

struct SystemModelDiscoveryHostResolver: ModelDiscoveryHostResolver {
    func resolve(host: String, port: Int) throws -> Set<ModelDiscoveryResolvedAddress> {
#if canImport(Darwin)
        var hints = addrinfo()
        hints.ai_flags = AI_ADDRCONFIG
        hints.ai_family = AF_UNSPEC
        hints.ai_socktype = Int32(SOCK_STREAM.rawValue)
        hints.ai_protocol = Int32(IPPROTO_TCP)

        var result: UnsafeMutablePointer<addrinfo>?
        let status = getaddrinfo(host, String(port), &hints, &result)
        guard status == 0, let first = result else {
            throw ModelDiscoveryNetworkError.destinationResolutionFailed
        }
        defer { freeaddrinfo(first) }

        var addresses: Set<ModelDiscoveryResolvedAddress> = []
        var current: UnsafeMutablePointer<addrinfo>? = first
        while let entry = current {
            let info = entry.pointee
            if let address = info.ai_addr {
                switch info.ai_family {
                case AF_INET:
                    let value = address.withMemoryRebound(
                        to: sockaddr_in.self,
                        capacity: 1
                    ) { pointer in
                        withUnsafeBytes(of: pointer.pointee.sin_addr) { raw in
                            Array(raw.prefix(4))
                        }
                    }
                    if value.count == 4 {
                        addresses.insert(.ipv4(value[0], value[1], value[2], value[3]))
                    }
                case AF_INET6:
                    let value = address.withMemoryRebound(
                        to: sockaddr_in6.self,
                        capacity: 1
                    ) { pointer in
                        withUnsafeBytes(of: pointer.pointee.sin6_addr) { raw in
                            Array(raw.prefix(16))
                        }
                    }
                    if value.count == 16 {
                        addresses.insert(.ipv6(value))
                    }
                default:
                    break
                }
            }
            current = info.ai_next
        }
        guard !addresses.isEmpty else {
            throw ModelDiscoveryNetworkError.destinationResolutionFailed
        }
        return addresses
#else
        throw ModelDiscoveryNetworkError.destinationResolutionFailed
#endif
    }
}
