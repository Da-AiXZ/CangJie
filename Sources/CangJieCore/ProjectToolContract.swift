import Foundation

public enum ProjectToolContractError: Error, Equatable, Sendable {
    case unsupportedTool
    case invalidArguments
    case invalidInvocationIdentity
}

public enum ProjectToolArguments: Equatable, Sendable {
    case create(title: String, premise: String)
    case list
    case status
    case switchProject(projectID: UUID)
    case saveDiscussion(title: String, body: String)
}

public struct ProjectToolInvocation: Equatable, Sendable {
    public static let maximumProviderCallIDUTF8Bytes = 512
    public static let maximumProviderCallIndex = 7
    public static let maximumTitleUTF8Bytes = 256
    public static let maximumPremiseUTF8Bytes = 8 * 1_024
    public static let maximumDiscussionBodyUTF8Bytes = 64 * 1_024

    public let providerCallID: String
    public let providerCallIndex: Int
    public let providerRequestID: UUID
    public let runID: UUID
    public let conversationID: UUID
    public let projectID: UUID?
    public let toolID: String
    public let toolVersion: String
    public let arguments: ProjectToolArguments
    public let inputHash: String

    public var idempotencyKey: String {
        "provider.tool.\(providerRequestID.canonicalString).\(providerCallIndex)"
    }

    public static func parse(
        providerFunctionName: String,
        argumentsJSON: String,
        providerCallID: String,
        providerCallIndex: Int,
        providerRequestID: UUID,
        runID: UUID,
        conversationID: UUID,
        projectID: UUID?
    ) throws -> ProjectToolInvocation {
        guard !providerCallID.isEmpty,
              providerCallID.utf8.count <= maximumProviderCallIDUTF8Bytes,
              !containsUnsafeControl(providerCallID),
              (0...maximumProviderCallIndex).contains(providerCallIndex) else {
            throw ProjectToolContractError.invalidInvocationIdentity
        }
        let definition: Definition
        let arguments: ProjectToolArguments
        switch providerFunctionName {
        case "project_create":
            definition = .create
            let decoded = try decodeCreateArguments(argumentsJSON)
            arguments = .create(title: decoded.title, premise: decoded.premise)
        case "project_list":
            definition = .list
            try decodeEmptyArguments(argumentsJSON)
            arguments = .list
        case "project_status":
            definition = .status
            try decodeEmptyArguments(argumentsJSON)
            arguments = .status
        case "project_switch":
            definition = .switchProject
            arguments = .switchProject(
                projectID: try decodeProjectIDArguments(argumentsJSON)
            )
        case "project_save_discussion":
            definition = .saveDiscussion
            let decoded = try decodeDiscussionArguments(argumentsJSON)
            arguments = .saveDiscussion(title: decoded.title, body: decoded.body)
        default:
            throw ProjectToolContractError.unsupportedTool
        }
        let inputHash = fingerprint(
            providerCallID: providerCallID,
            providerCallIndex: providerCallIndex,
            providerRequestID: providerRequestID,
            runID: runID,
            conversationID: conversationID,
            projectID: projectID,
            definition: definition,
            arguments: arguments
        )
        return ProjectToolInvocation(
            providerCallID: providerCallID,
            providerCallIndex: providerCallIndex,
            providerRequestID: providerRequestID,
            runID: runID,
            conversationID: conversationID,
            projectID: projectID,
            toolID: definition.toolID,
            toolVersion: definition.version,
            arguments: arguments,
            inputHash: inputHash
        )
    }

    private enum Definition {
        case create
        case list
        case status
        case switchProject
        case saveDiscussion

        var toolID: String {
            switch self {
            case .create:
                return "project.create"
            case .list:
                return "project.list"
            case .status:
                return "project.status"
            case .switchProject:
                return "project.switch"
            case .saveDiscussion:
                return "conversation.save_discussion"
            }
        }

        var version: String { "1" }
    }

    private struct CreateArguments: Decodable {
        let title: String
        let premise: String

        init(from decoder: Decoder) throws {
            let raw = try decoder.container(keyedBy: DynamicCodingKey.self)
            guard Set(raw.allKeys.map(\.stringValue)) == ["premise", "title"] else {
                throw ProjectToolContractError.invalidArguments
            }
            guard let titleKey = DynamicCodingKey(stringValue: "title"),
                  let premiseKey = DynamicCodingKey(stringValue: "premise") else {
                throw ProjectToolContractError.invalidArguments
            }
            title = try raw.decode(String.self, forKey: titleKey)
            premise = try raw.decode(String.self, forKey: premiseKey)
        }
    }

    private struct DynamicCodingKey: CodingKey {
        let stringValue: String
        let intValue: Int?

        init?(stringValue: String) {
            self.stringValue = stringValue
            intValue = nil
        }

        init?(intValue: Int) {
            stringValue = String(intValue)
            self.intValue = intValue
        }
    }

    private static func decodeCreateArguments(
        _ json: String
    ) throws -> CreateArguments {
        guard json.utf8.count <= maximumTitleUTF8Bytes
                + maximumPremiseUTF8Bytes + 128,
              let data = json.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(
                CreateArguments.self,
                from: data
              ),
              validText(
                decoded.title,
                maximumUTF8Bytes: maximumTitleUTF8Bytes
              ),
              validText(
                decoded.premise,
                maximumUTF8Bytes: maximumPremiseUTF8Bytes
              ) else {
            throw ProjectToolContractError.invalidArguments
        }
        return decoded
    }

    private static func decodeEmptyArguments(_ json: String) throws {
        guard json.utf8.count <= 128,
              let data = json.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              let dictionary = object as? [String: Any],
              dictionary.isEmpty else {
            throw ProjectToolContractError.invalidArguments
        }
    }

    private struct ProjectIDArguments: Decodable {
        let projectID: UUID

        init(from decoder: Decoder) throws {
            let raw = try decoder.container(keyedBy: DynamicCodingKey.self)
            guard Set(raw.allKeys.map(\.stringValue)) == ["projectID"],
                  let key = DynamicCodingKey(stringValue: "projectID"),
                  let projectID = UUID(
                    uuidString: try raw.decode(String.self, forKey: key)
                  ) else {
                throw ProjectToolContractError.invalidArguments
            }
            self.projectID = projectID
        }
    }

    private struct DiscussionArguments: Decodable {
        let title: String
        let body: String

        init(from decoder: Decoder) throws {
            let raw = try decoder.container(keyedBy: DynamicCodingKey.self)
            guard Set(raw.allKeys.map(\.stringValue)) == ["body", "title"],
                  let titleKey = DynamicCodingKey(stringValue: "title"),
                  let bodyKey = DynamicCodingKey(stringValue: "body") else {
                throw ProjectToolContractError.invalidArguments
            }
            title = try raw.decode(String.self, forKey: titleKey)
            body = try raw.decode(String.self, forKey: bodyKey)
        }
    }

    private static func decodeProjectIDArguments(_ json: String) throws -> UUID {
        guard json.utf8.count <= 256,
              let data = json.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(
                ProjectIDArguments.self,
                from: data
              ) else {
            throw ProjectToolContractError.invalidArguments
        }
        return decoded.projectID
    }

    private static func decodeDiscussionArguments(
        _ json: String
    ) throws -> DiscussionArguments {
        guard json.utf8.count <= maximumTitleUTF8Bytes
                + maximumDiscussionBodyUTF8Bytes + 128,
              let data = json.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(
                DiscussionArguments.self,
                from: data
              ),
              validText(
                decoded.title,
                maximumUTF8Bytes: maximumTitleUTF8Bytes
              ),
              validText(
                decoded.body,
                maximumUTF8Bytes: maximumDiscussionBodyUTF8Bytes
              ) else {
            throw ProjectToolContractError.invalidArguments
        }
        return decoded
    }

    private static func validText(
        _ value: String,
        maximumUTF8Bytes: Int
    ) -> Bool {
        value == value.trimmingCharacters(in: .whitespacesAndNewlines)
            && !value.isEmpty
            && value.utf8.count <= maximumUTF8Bytes
            && !containsUnsafeControl(value)
    }

    private static func containsUnsafeControl(_ value: String) -> Bool {
        ModelConnection.containsUnsafeDisplayControl(value)
    }

    private static func fingerprint(
        providerCallID: String,
        providerCallIndex: Int,
        providerRequestID: UUID,
        runID: UUID,
        conversationID: UUID,
        projectID: UUID?,
        definition: Definition,
        arguments: ProjectToolArguments
    ) -> String {
        var encoder = CanonicalFieldEncoder()
        encoder.append(name: "schema", value: "cangjie.project-tool-input.v1")
        encoder.append(name: "providerCallID", value: providerCallID)
        encoder.append(name: "providerCallIndex", value: String(providerCallIndex))
        encoder.append(name: "providerRequestID", value: providerRequestID.canonicalString)
        encoder.append(name: "runID", value: runID.canonicalString)
        encoder.append(name: "conversationID", value: conversationID.canonicalString)
        encoder.append(name: "projectID", value: projectID?.canonicalString ?? "")
        encoder.append(name: "toolID", value: definition.toolID)
        encoder.append(name: "toolVersion", value: definition.version)
        switch arguments {
        case let .create(title, premise):
            encoder.append(name: "title", value: title)
            encoder.append(name: "premise", value: premise)
        case .list:
            encoder.append(name: "arguments", value: "empty")
        case .status:
            encoder.append(name: "arguments", value: "empty")
        case let .switchProject(projectID):
            encoder.append(name: "projectID", value: projectID.canonicalString)
        case let .saveDiscussion(title, body):
            encoder.append(name: "title", value: title)
            encoder.append(name: "body", value: body)
        }
        return CangJieSHA256.digest(encoder.bytes).hexadecimalString
    }
}
