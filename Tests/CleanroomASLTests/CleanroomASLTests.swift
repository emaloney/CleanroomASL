//
//  CleanroomASLTests.swift
//  Cleanroom Project
//
//  Created by Evan Maloney on 4/6/15.
//  Copyright © 2015 Gilt Groupe. All rights reserved.
//

import XCTest
import Foundation
import CleanroomASL

class CleanroomASLTests: XCTestCase
{
    let sender = "com.gilt.cleanroom.tests.ASL"
    let testMessages = ASLPriorityLevel.allValues().map{ ($0, "Logging a test message with \($0.priorityString) priority (#\($0.rawValue))") }

    func write(message: String, at priorityLevel: ASLPriorityLevel, using client: ASLClient)
    {
        let msg = ASLMessageObject(priorityLevel: priorityLevel, message: message)
        client.log(msg, logSynchronously: true)
    }

    func writeTestMessages(client: ASLClient)
    {
        for (priority, message) in testMessages {
            write(message: message, at: priority, using: client)
        }
    }

    func verifyTestMessages(client: ASLClient, sentSince date: NSDate)
    {
        let query = ASLQueryObject()
        query.setQuery(key: .sender, value: sender, operation: .equalTo, modifiers: .none)
        query.setQuery(key: .message, value: nil, operation: .keyExists, modifiers: .none)
        query.setQuery(key: .time, value: Int(date.timeIntervalSince1970), operation: .greaterThanOrEqualTo, modifiers: .none)

        let signal = NSCondition()

        signal.lock()
        signal.wait(until: Date(timeIntervalSinceNow: 1))
        signal.unlock()

        var gotFinalResult = false

        // .Info and .Debug messages aren't committed to storage,
        // so wec won't get these back in the query
        var remainingToFind = Set(testMessages.filter{ $0.0.rawValue <= ASLPriorityLevel.notice.rawValue }.map{ $0.1 })

        client.search(query) { result in

            if let result = result {
                print("")
                for key in result.attributes.keys.sorted() {
                    print("\t\(key): \(result.attributes[key] ?? "(nil)")")
                }

                remainingToFind.remove(result.message)
            }

            signal.lock()
            gotFinalResult = result == nil
            if gotFinalResult {
                signal.signal()
            }
            signal.unlock()

            return true
        }

        signal.lock()
        while !gotFinalResult {
            signal.wait()
        }
        signal.unlock()

        XCTAssert(remainingToFind.isEmpty)
    }

    func testStandardLogging()
    {
        let startTime = NSDate()

        let client = ASLClient(sender: sender)

        writeTestMessages(client: client)

        verifyTestMessages(client: client, sentSince: startTime)
    }

    func testWritingToNewLogFile()
    {
        let filePath = "/tmp/\(sender)-\(ProcessInfo().globallyUniqueString)-test-data-store.asl"

        let startTime = NSDate()

        var client: ASLClient? = ASLClient(filePath: filePath, sender: sender, openFileForWriting: true)

        writeTestMessages(client: client!)

        // clearing out the client ensures the file buffer is flushed
        // so our test messages can be found by verifyTestMessages()
        client = nil

        client = ASLClient(filePath: filePath)

        verifyTestMessages(client: client!, sentSince: startTime)
    }

    func testQueryExistingLogFile()
    {
        let testBundle = Bundle(for: type(of: self))
        let testFile = testBundle.path(forResource: "test.asl", ofType: nil)

        let client = ASLClient(filePath: testFile)

        let query = ASLQueryObject()
        query.setQuery(key: .aslMessageID, value: 4255, operation: .greaterThanOrEqualTo, modifiers: .none)
        query.setQuery(key: .sender, value: "PetriDish", operation: .equalTo, modifiers: .none)
        query.setQuery(attributeName: "CleanroomLogger.severity", value: 3, operation: .greaterThanOrEqualTo, modifiers: .none)

        let signal = NSCondition()

        signal.lock()
        signal.wait(until: Date(timeIntervalSinceNow: 1))
        signal.unlock()

        var gotFinalResult = false

        var messages = [String]()

        client.search(query) { result in

            if let result = result {
                print("")
                for key in result.attributes.keys.sorted() {
                    print("\t\(key): \(result.attributes[key] ?? "(nil)")")
                }

                messages.append(result.message)
            }

            signal.lock()
            gotFinalResult = result == nil
            if gotFinalResult {
                signal.signal()
            }
            signal.unlock()

            return true
        }

        signal.lock()
        while !gotFinalResult {
            signal.wait()
        }
        signal.unlock()

        XCTAssert(messages.count == 2)
        XCTAssertEqual(messages[0], "2016-08-23 17:07:01.419 EDT |    INFO | DeepLinkTarget+NavigationUI.swift:72 - Can't determine correct DeepLinkEditor to return for DiagnosticsConsole")
        XCTAssertEqual(messages[1], "2016-08-23 17:07:01.424 EDT |    INFO | DeepLinkConsoleOutput.swift:97 - Successfully navigated to DiagnosticsConsole")
    }
}
