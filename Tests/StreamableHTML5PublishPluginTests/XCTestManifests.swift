import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(StreamableHTML5PublishPluginTests.allTests),
    ]
}
#endif
