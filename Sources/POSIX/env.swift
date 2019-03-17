/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2014 - 2017 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See http://swift.org/LICENSE.txt for license information
 See http://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

#if os(Windows)
import ucrt
#else
import func SPMLibc.getenv
import func SPMLibc.setenv
import func SPMLibc.unsetenv
import var SPMLibc.errno
#endif

public func getenv(_ key: String) -> String? {
#if os(Windows)
    return String(cString: ucrt.getenv(key))
#else
    let out = SPMLibc.getenv(key)
    return out == nil ? nil : String(validatingUTF8: out!)  //FIXME locale may not be UTF8
#endif
}

public func setenv(_ key: String, value: String) throws {
#if os(Windows)
    guard ucrt._putenv("\(key)=\(value)") == 0 else {
        var errno: Int32 = 0
        _get_errno(&errno)
        throw SystemError.setenv(errno, key)
    }
#else
    guard SPMLibc.setenv(key, value, 1) == 0 else {
        throw SystemError.setenv(errno, key)
    }
#endif
}

public func unsetenv(_ key: String) throws {
#if os(Windows)
    guard ucrt._putenv("\(key)=") == 0 else {
        var errno: Int32 = 0
        _get_errno(&errno)
        throw SystemError.unsetenv(errno, key)
    }
#else
    guard SPMLibc.unsetenv(key) == 0 else {
        throw SystemError.unsetenv(errno, key)
    }
#endif
}
