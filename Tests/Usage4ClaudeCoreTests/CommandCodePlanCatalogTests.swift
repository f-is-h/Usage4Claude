import XCTest
@testable import Usage4ClaudeCore

/// Tests for `CommandCodePlanCatalog` — plan ID → monthly credit allowance.
final class CommandCodePlanCatalogTests: XCTestCase {

    func testExactLookups() {
        XCTAssertEqual(CommandCodePlanCatalog.plan(forID: "individual-go")?.displayName, "Go")
        XCTAssertEqual(CommandCodePlanCatalog.plan(forID: "individual-go")?.monthlyCreditsUSD, 10)
        XCTAssertEqual(CommandCodePlanCatalog.plan(forID: "individual-goat")?.monthlyCreditsUSD, 70)
        XCTAssertEqual(CommandCodePlanCatalog.plan(forID: "individual-max")?.monthlyCreditsUSD, 150)
        XCTAssertEqual(CommandCodePlanCatalog.plan(forID: "individual-ultra")?.monthlyCreditsUSD, 300)
        XCTAssertEqual(CommandCodePlanCatalog.plan(forID: "teams-pro")?.monthlyCreditsUSD, 40)
    }

    /// "individual-pro-v1" must not be shadowed by the shorter "individual-pro".
    func testProV1BeatsPro() {
        XCTAssertEqual(CommandCodePlanCatalog.plan(forID: "individual-pro-v1")?.monthlyCreditsUSD, 80)
        XCTAssertEqual(CommandCodePlanCatalog.plan(forID: "individual-pro")?.monthlyCreditsUSD, 30)
    }

    /// "individual-provider" must not be shadowed by the shorter "individual-pro".
    func testProviderBeatsPro() {
        XCTAssertEqual(CommandCodePlanCatalog.plan(forID: "individual-provider")?.displayName, "Provider")
        XCTAssertEqual(CommandCodePlanCatalog.plan(forID: "individual-provider")?.monthlyCreditsUSD, 15)
    }

    func testLookupIsCaseAndSeparatorInsensitive() {
        XCTAssertEqual(CommandCodePlanCatalog.plan(forID: "Individual-Goat")?.monthlyCreditsUSD, 70)
        XCTAssertEqual(CommandCodePlanCatalog.plan(forID: "individual_pro")?.monthlyCreditsUSD, 30)
    }

    func testUnknownPlanYieldsNil() {
        XCTAssertNil(CommandCodePlanCatalog.plan(forID: "enterprise-custom"))
        XCTAssertNil(CommandCodePlanCatalog.plan(forID: ""))
        XCTAssertNil(CommandCodePlanCatalog.plan(forID: "   "))
    }

    func testUnrecognizedVariantFallsBackToLongestPrefix() {
        // A future monthly variant should still size from "individual-goat".
        XCTAssertEqual(CommandCodePlanCatalog.plan(forID: "individual-goat-yearly")?.monthlyCreditsUSD, 70)
    }
}
