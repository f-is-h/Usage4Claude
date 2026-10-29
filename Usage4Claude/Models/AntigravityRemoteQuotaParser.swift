import Foundation

nonisolated enum AntigravityRemoteQuotaParser {
    static func parse(_ response: [String: Any]) throws -> AntigravityUsageData {
        let payload = response["response"] as? [String: Any] ?? response["summary"] as? [String: Any] ?? response
        guard let groups = payload["groups"] as? [[String: Any]] else { throw AntigravityParseError.malformed }
        let normalized: [[String: Any]] = groups.map { group in
            let buckets = (group["buckets"] as? [[String: Any]] ?? []).compactMap { bucket -> [String: Any]? in
                guard bucket["disabled"] as? Bool != true else { return nil }
                let remaining = bucket["remaining"] as? [String: Any] ?? [:]
                let explicit = bucket["remainingFraction"] as? Double ?? remaining["remainingFraction"] as? Double ??
                    (remaining["case"] as? String == "remainingFraction" ? remaining["value"] as? Double : nil)
                // proto3 JSON 省略零值字段：用尽的桶没有 remainingFraction，但仍带窗口信息
                let exhausted: Double? = bucket["window"] != nil && remaining["case"] == nil ? 0 : nil
                guard let fraction = explicit ?? exhausted,
                    fraction.isFinite, (0...1).contains(fraction) else { return nil }
                var value: [String: Any] = ["id": bucket["bucketId"] ?? bucket["id"] ?? "",
                    "remaining_fraction": fraction]
                value["window"] = bucket["window"]
                value["reset_time"] = bucket["resetTime"]
                return value
            }
            return ["name": group["displayName"] ?? group["name"] ?? "", "buckets": buckets]
        }
        let data = try JSONSerialization.data(withJSONObject: ["status": "SUCCESS", "command": ["name": "usage", "data": ["groups": normalized]]])
        let result = try AntigravityUsageParser.parse(cliOutput: String(decoding: data, as: UTF8.self))
        guard result.hasAnyLimit else { throw AntigravityParseError.malformed }
        return result
    }
}
