import XCTest

import SwiftUnusedTests

var tests = [XCTestCaseEntry]()
tests += SwiftUnusedTests.allTests()
XCTMain(tests)