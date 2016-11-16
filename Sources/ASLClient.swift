//
//  ASLClient.swift
//  CleanroomASL
//
//  Created by Evan Maloney on 3/17/15.
//  Copyright © 2015 Gilt Groupe. All rights reserved.
//

import Foundation

#if SWIFT_PACKAGE   // we import ASL as a module only when building with the
import ASL                  // Swift Package Manager (SPM); in Xcode, the use the
#endif                      // bridging header to import the ASL API

/**
 `ASLClient` instances maintain a client connection to the ASL daemon, and can
 used to perform logging and to execute log search queries.

 **Note:** Because the underlying client connection is not intended to be shared
 across threads, each `ASLClient` has an associated GCD serial queue used to
 ensure that the underlying ASL client connection is only ever used from a single
 thread.
 */
public class ASLClient
{
    /**
     Represents ASL client creation option values, which are used to determine
     the behavior of an `ASLClient`. These are bit-flag values that can be
     combined and otherwise manipulated with bitwise operators.
     */
    public struct Options: OptionSet
    {
        /// The raw representation of the receiving `ASLClient.Options` value.
        public let rawValue: UInt32

        /**
         Initializes a new `ASLClient.Options` value with the specified
         raw value.

         - parameter rawValue: A `UInt32` value containing the raw bit flag
         values to use.
         */
        public init(rawValue: UInt32) { self.rawValue = rawValue }

        /// An `ASLClient.Options` value wherein none of the bit flags are set.
        public static let none      = Options(rawValue: 0)

        /// An `ASLClient.Options` value with the `ASL_OPT_STDERR` flag set.
        public static let stdErr    = Options(rawValue: 0x00000001)

        /// An `ASLClient.Options` value with the `ASL_OPT_NO_DELAY` flag set.
        public static let noDelay   = Options(rawValue: 0x00000002)

        /// An `ASLClient.Options` value with the `ASL_OPT_NO_REMOTE` flag set.
        public static let noRemote  = Options(rawValue: 0x00000004)
    }

    /// The string that will be used by ASL the *sender* of any log messages
    /// passed to the receiver's `log()` function.
    public let sender: String

    /// The string that will be used by ASL the *facility* of any log messages
    /// passed to the receiver's `log()` function.
    public let facility: String

    /// The receiver's filter mask.
    public let filterMask: Int32

    /// If `true`, the receiver is mirroring log entries in raw form to the
    /// standard error stream; `false` otherwise.
    public let useRawStdErr: Bool

    /// The `ASLClient.Options` value that determines the behavior of ASL.
    public let options: Options

    /// The GCD queue used to serialize log operations. This is exposed to
    /// allow low-level ASL operations not supported by `ASLClient` to be
    /// performed using the underlying `aslclient`. This queue must be used for
    /// all ASL operations using the receiver's `client` property.
    public let queue: DispatchQueue

    /// Determines whether the receiver's connection to the ASL is open.
    public var isOpen: Bool { return client != nil }

    /// The `aslclient` associated with the receiver.
    public let client: aslclient?

    /// If the client was instantiated using an ASL message data store file, 
    /// this value contains the filesystem path of that file.
    public let filePath: String?

    /**
     Initializes a new `ASLClient` instance.

     - parameter filePath: The filesystem path of an ASL message data store 
     file. If this parameter is provided and the file exists, the client
     can be used to query any existing entries and to log additional entries.
     If the file does not exist, an attempt will be made to create it.

     - parameter sender: Will be used as the `ASLAttributeKey` value for the
     `.Sender` key for all log messages sent to ASL. If `nil`, the name of the
     running process is used.

     - parameter facility: Will be used as the `ASLAttributeKey` value for the
     `.Facility` key for all log messages sent to ASL. If `nil`, the string
     "`com.gilt.cleanroomASL`" is used.

     - parameter filterMask: Specifies the priority filter that should be
     applied to messages sent to the log.

     - parameter useRawStdErr: If `true`, messages sent through the `ASLClient`
     will be mirrored to standard error without modification. Note that this
     differs from the behavior of the `.StdErr` value for the
     `ASLClient.Options` parameter, which performs some escaping and may add
     additional text to the message.

     - parameter openFileForWriting: If `filePath` is non-`nil`, this value
     determines whether the file will be opened for writing. If `true` and
     `filePath` doesn't exist, an attempt will be made to create a new message
     data store at that path. If `false`, it will only be possible to
     query the file.

     - parameter options: An `ASLClient.Options` value specifying the client
     options to be used by this new client. Note that if the `.StdErr` value
     is passed and `rawStdErr` is also `true`, the behavior of `rawStdErr`
     will be used, overriding the `.StdErr` behavior.
    */
    public init(filePath: String? = nil, sender: String? = nil, facility: String? = nil, filterMask: Int32 = ASLPriorityLevel.debug.filterMaskUpTo, useRawStdErr: Bool = true, openFileForWriting: Bool = false, options: Options = .noRemote)
    {
        self.sender = sender ?? ProcessInfo.processInfo.processName
        self.facility = facility ?? "com.gilt.CleanroomASL"
        self.filterMask = filterMask
        self.useRawStdErr = useRawStdErr
        self.options = options
        self.queue = DispatchQueue(label: "ASLClient", attributes: [])

        var options = self.options.rawValue
        if self.useRawStdErr {
            options &= ~Options.stdErr.rawValue
        }

        if let filePath = filePath {
            self.client = asl_open_path(filePath, openFileForWriting ? UInt32(ASL_OPT_OPEN_WRITE | ASL_OPT_CREATE_STORE) : 0)
        }
        else {
            self.client = asl_open(self.sender, self.facility, options)
        }

        self.filePath = filePath

        asl_set_filter(self.client, self.filterMask)

        if self.useRawStdErr {
            asl_add_output_file(self.client, 2, ASL_MSG_FMT_MSG, ASL_TIME_FMT_LCL, self.filterMask, ASL_ENCODE_NONE)
        }
    }

    deinit {
        asl_close(client)
    }

    private func dispatcher(_ currentQueue: DispatchQueue? = nil, synchronously: Bool = false)
        -> (@escaping () -> Void) -> Void
    {
        let dispatcher: (@escaping () -> Void) -> Void = { [queue] block in
            let shouldDispatch = currentQueue == nil || !queue.isEqual(currentQueue!)
            if shouldDispatch {
                if synchronously {
                    return queue.sync(execute: block)
                } else {
                    return queue.async(execute: block)
                }
            }
            else {
                block()
            }
        }
        return dispatcher
    }

    /**
     Sends the message to the Apple System Log.

     - parameter message: the `ASLMessageObject` to send to Apple System Log.

     - parameter logSynchronously: If `true`, the `log()` function will perform
     synchronously. You should **not** set this to `true` in production code;
     it will degrade performance. Synchronous logging can be useful when
     debugging to ensure that up-to-date log messages are visible in the
     console.

     - parameter currentQueue: If the log message is already being processed on a
     given GCD queue, a reference to that queue should be passed in. That way,
     if `currentQueue` has the same value as the receiver's `queue` property,
     no additional dispatching will take place. This is needed to avoid
     deadlocks when external code directly uses the receiver's queue to perform
     operations related to logging.
     */
    public func log(_ message: ASLMessageObject, logSynchronously: Bool = false, currentQueue: DispatchQueue? = nil)
    {
        let dispatch = dispatcher(currentQueue, synchronously: logSynchronously)
        dispatch {
            if message[.readUID] == nil {
                // the .readUID attribute determines the processes that can
                // read this log entry. -1 means anyone can read.
                message[.readUID] = "-1"
            }

            if self.filePath != nil {
                // if we were instantiated using a file, the sender and
                // facility weren't set via the usual call to asl_open();
                // set these values manually (if they weren't already 
                // provided within the message)
                if message[.sender] == nil {
                    message[.sender] = self.sender
                }
                if message[.facility] == nil {
                    message[.facility] = self.facility
                }

                // also, when the client was opened with asl_open_path(), it
                // seems that the ASL_KEY_TIME and ASL_KEY_TIME_NSEC attributes
                // aren't set as they normally are as with asl_open()
                if message[.time] == nil && message[.timeNanoSec] == nil {
                    var time = timeval()
                    if gettimeofday(&time, nil) == 0 {
                        message[.time] = String(time.tv_sec)
                        message[.timeNanoSec] = String(time.tv_usec * 1000)
                    }
                }
            }

            asl_send(self.client, message.aslObject)

            if logSynchronously && (self.useRawStdErr || self.options.contains(.stdErr)) {
                // flush stderr to ensure the console is up-to-date if we hit a breakpoint
                fflush(stderr)
            }
        }
    }

    /**
     Asynchronously reads the ASL log, issuing one call to the callback function
     for each relevant entry in the log.

     Only entries that have a valid timestamp and message will be provided to
     the callback.

     - parameter query: The `ASLQueryObject` representing the search query

     - parameter callback: The callback function to be invoked for each log
     entry. Make no assumptions about which thread will be calling the function.
    */
    public func search(_ query: ASLQueryObject, callback: @escaping ASLQueryObject.ResultCallback)
    {
        let dispatch = dispatcher()
        dispatch {
            let results = asl_search(self.client, query.aslObject)

            var keepGoing = true
            var record = asl_next(results)
            while record != nil && keepGoing {
                if let message = record![.message] {
                    if let timestampStr = record![.time] {
                        if let timestampInt = Int(timestampStr) {
                            var timestamp = TimeInterval(timestampInt)

                            if let nanoStr = record![.timeNanoSec] {
                                if let nanoInt = Int(nanoStr) {
                                    let nanos = Double(nanoInt) / Double(NSEC_PER_SEC)
                                    timestamp += nanos
                                }
                            }

                            let logEntryTime = Date(timeIntervalSince1970: timestamp)

                            var priority = ASLPriorityLevel.notice
                            if let logLevelStr = record![.level],
                                let logLevelInt = Int(logLevelStr),
                                let level = ASLPriorityLevel(rawValue: Int32(logLevelInt))
                            {
                                priority = level
                            }

                            var attr = [String: String]()
                            var i = UInt32(0)
                            var key = asl_key(record, i)
                            while key != nil {
                                let keyStr = String(cString: key!)
                                if let val = record![keyStr] {
                                    attr[keyStr] = val
                                }
                                i += 1
                                key = asl_key(record, i)
                            }

                            let record = ASLQueryObject.ResultRecord(client: self, query: query, priority: priority, message: message, timestamp: logEntryTime, attributes: attr)
                            keepGoing = callback(record)
                        }
                    }
                }
                record = asl_next(results)
            }

            if keepGoing {
                _ = callback(nil)
            }

            asl_release(results)
        }
    }
}
