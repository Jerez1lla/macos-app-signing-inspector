import Foundation

protocol DesignatedRequirementOutputParsing: Sendable {
    func parse(_ result: ProcessResult) -> DesignatedRequirementInspection
}
