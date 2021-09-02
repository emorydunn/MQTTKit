//
//  File.swift
//  
//
//  Created by Timothy Wise on 9/2/21.
//

import Foundation

class FileHandleInputStream: InputStream {

    private let fileHandle: FileHandle

    private var _streamStatus: Stream.Status
    private var _streamError: Error?
    private var _delegate: StreamDelegate?

    init(fileHandle: FileHandle, offset: UInt64 = 0) {
        self.fileHandle = fileHandle
        if offset > 0 {
            self.fileHandle.seek(toFileOffset: offset)
        }
        self._streamStatus = .notOpen
        self._streamError = nil
        super.init(data: Data())
    }

    override var streamStatus: Stream.Status { _streamStatus }
    override var streamError: Error? { _streamError }

    override var delegate: StreamDelegate? {
        get {
            return _delegate
        }
        set {
            _delegate = newValue
        }
    }

    override func open() {
        guard self._streamStatus != .open else { return }

        _ = NotificationCenter.default.addObserver(forName: Notification.Name.NSFileHandleDataAvailable, object: self.fileHandle, queue: nil) { notification in
            #if os(Linux)
            self._delegate?.stream(self, handle: .hasBytesAvailable)
            #else
            self._delegate?.stream?(self, handle: .hasBytesAvailable)
            #endif
        }
        // Must be called from a thread that has an active runloop, see https://developer.apple.com/documentation/foundation/nsfilehandle/1409270-waitfordatainbackgroundandnotify
        DispatchQueue.main.async { self.fileHandle.waitForDataInBackgroundAndNotify() }
        self._streamStatus = .open
        #if os(Linux)
        self.delegate?.stream(self, handle: .openCompleted)
        #else
        self.delegate?.stream?(self, handle: .openCompleted)
        #endif
    }

    //override var hasBytesAvailable: Bool { true }

    override func read(_ buffer: UnsafeMutablePointer<UInt8>, maxLength len: Int) -> Int {
        guard _streamStatus == .open else { return 0 }
        guard let data = try? self.fileHandle.read(upToCount: 1) else {
            #if os(Linux)
            self._delegate?.stream(self, handle: .endEncountered)
            #else
            self._delegate?.stream?(self, handle: .endEncountered)
            #endif
            return 0
        }
        if data.count > 0 {
            buffer[0] = data[0]
            self.fileHandle.waitForDataInBackgroundAndNotify()
        }
        return data.count
    }

    override func close() {
        self._streamStatus = .closed
    }

    override func getBuffer(_ buffer: UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>, length len: UnsafeMutablePointer<Int>) -> Bool { false }
    #if !os(Linux)
    override func property(forKey key: Stream.PropertyKey) -> Any? { nil }
    override func setProperty(_ property: Any?, forKey key: Stream.PropertyKey) -> Bool { false }
    #endif
    override func schedule(in aRunLoop: RunLoop, forMode mode: RunLoop.Mode) { }
    override func remove(from aRunLoop: RunLoop, forMode mode: RunLoop.Mode) { }
}

class FileHandleOutputStream: OutputStream {

    private let fileHandle: FileHandle

    private var _streamStatus: Stream.Status
    private var _streamError: Error?
    private var _delegate: StreamDelegate?

    init(fileHandle: FileHandle) {
        self.fileHandle = fileHandle
        self._streamStatus = .notOpen
        self._streamError = nil
        super.init(toMemory: ())
    }

    #if os(Linux)
    required public init(toMemory: ()) {
        fatalError("unsupported")
    }
    #endif

    override var streamStatus: Stream.Status { _streamStatus }
    override var streamError: Error? { _streamError }

    override var delegate: StreamDelegate? {
        get {
            return _delegate
        }
        set {
            _delegate = newValue
        }
    }

    override func open() {
        guard self._streamStatus != .open else { return }
        self._streamStatus = .open
        self.reportDelegateEvent(.openCompleted)
        self.reportDelegateEvent(.hasSpaceAvailable)
    }

    override var hasSpaceAvailable: Bool { true }

    override func write(_ buffer: UnsafePointer<UInt8>, maxLength len: Int) -> Int {

        let data = Data(bytes: buffer, count: len)
        self.fileHandle.write(data)
        self.reportDelegateEvent(.hasSpaceAvailable)
        return len
    }

    override func close() {
        self._streamStatus = .closed
    }

    #if !os(Linux)
    override func property(forKey key: Stream.PropertyKey) -> Any? { nil }
    override func setProperty(_ property: Any?, forKey key: Stream.PropertyKey) -> Bool { false }
    #endif
    override func schedule(in aRunLoop: RunLoop, forMode mode: RunLoop.Mode) { }
    override func remove(from aRunLoop: RunLoop, forMode mode: RunLoop.Mode) { }
}

private extension FileHandleOutputStream {

    func reportDelegateEvent(_ event: Stream.Event) {
        DispatchQueue.main.async {
            #if os(Linux)
            self._delegate?.stream(self, handle: event)
            #else
            self._delegate?.stream?(self, handle: event)
            #endif
        }
    }
}
