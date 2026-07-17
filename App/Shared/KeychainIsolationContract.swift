import Foundation
import Security

enum KeychainIsolationContract {
    static let mainAccessGroup = "com.juyang.CangJie"
    static let probeAccessGroup = "com.juyang.CangJie.KeychainIsolationProbe"

    static let canaryService = "com.juyang.CangJie.isolation-canary.v1"
    static let canaryAccount = "current-canary"

    static let probeControlService = "com.juyang.CangJie.KeychainIsolationProbe.control.v1"
    static let probeControlAccount = "own-group-control"
}

enum IsolationCheckDisposition: String, Equatable {
    case pass
    case criticalFail
    case inconclusive
}

struct KeychainIsolationCheck: Equatable {
    let disposition: IsolationCheckDisposition
    let status: OSStatus
    let detail: String
}

struct KeychainIsolationReport: Equatable {
    let ownGroupControl: KeychainIsolationCheck
    let defaultGroupLookup: KeychainIsolationCheck
    let forbiddenGroupLookup: KeychainIsolationCheck

    var overallDisposition: IsolationCheckDisposition {
        let dispositions = [
            ownGroupControl.disposition,
            defaultGroupLookup.disposition,
            forbiddenGroupLookup.disposition
        ]
        if dispositions.contains(.criticalFail) {
            return .criticalFail
        }
        if dispositions.allSatisfy({ $0 == .pass }) {
            return .pass
        }
        return .inconclusive
    }
}
