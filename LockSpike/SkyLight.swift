import Foundation

/// Private SkyLight space calls, resolved at runtime so a missing symbol returns nil instead of crashing at launch.
struct SkyLight {
    private typealias MainConnection = @convention(c) () -> Int32
    private typealias SpaceCreate = @convention(c) (Int32, Int32, UnsafeRawPointer?) -> UInt64
    private typealias SetLevel = @convention(c) (Int32, UInt64, Int32) -> Int32
    private typealias AddWindows = @convention(c) (Int32, UInt64, CFArray, Int32) -> Int32
    private typealias SpacesCall = @convention(c) (Int32, CFArray) -> Int32
    private typealias SpaceDestroy = @convention(c) (Int32, UInt64) -> Int32
    private typealias WindowsToSpaces = @convention(c) (Int32, CFArray, CFArray) -> Int32
    private typealias MoveToManaged = @convention(c) (Int32, CFArray, UInt64) -> Int32

    private let connection: Int32
    private let create: SpaceCreate
    private let setLevel: SetLevel
    private let addWindows: AddWindows
    private let show: SpacesCall
    private let hide: SpacesCall
    private let destroy: SpaceDestroy
    private let addToSpaces: WindowsToSpaces?
    private let moveToManaged: MoveToManaged?

    /// Returns nil and names the missing symbol through `log`.
    static func load(log: (String) -> Void) -> SkyLight? {
        guard let handle = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_NOW) else {
            log("dlopen SkyLight failed"); return nil
        }
        func sym<T>(_ name: String, as _: T.Type) -> T? {
            guard let p = dlsym(handle, name) else { log("missing symbol \(name)"); return nil }
            return unsafeBitCast(p, to: T.self)
        }
        guard let main = sym("SLSMainConnectionID", as: MainConnection.self),
              let create = sym("SLSSpaceCreate", as: SpaceCreate.self),
              let setLevel = sym("SLSSpaceSetAbsoluteLevel", as: SetLevel.self),
              let add = sym("SLSSpaceAddWindowsAndRemoveFromSpaces", as: AddWindows.self),
              let show = sym("SLSShowSpaces", as: SpacesCall.self),
              let hide = sym("SLSHideSpaces", as: SpacesCall.self),
              let destroy = sym("SLSSpaceDestroy", as: SpaceDestroy.self)
        else { return nil }
        return SkyLight(connection: main(), create: create, setLevel: setLevel, addWindows: add,
                        show: show, hide: hide, destroy: destroy,
                        addToSpaces: dlsym(handle, "SLSAddWindowsToSpaces").map { unsafeBitCast($0, to: WindowsToSpaces.self) },
                        moveToManaged: dlsym(handle, "SLSMoveWindowsToManagedSpace").map { unsafeBitCast($0, to: MoveToManaged.self) })
    }

    /// Creates a space at `level`, moves the window into it and shows it. Returns the space id and each call's status.
    func present(windowID: Int, level: Int32) -> (space: UInt64, statuses: [String: Int32]) {
        let space = create(connection, 1, nil)
        let spaces = [NSNumber(value: space)] as CFArray
        var s: [String: Int32] = [:]
        s["setLevel"] = setLevel(connection, space, level)
        s["show"] = show(connection, spaces)
        let windows = [NSNumber(value: windowID)] as CFArray
        s["addWindows"] = addWindows(connection, space, windows, 7)
        s["addToSpaces"] = addToSpaces?(connection, windows, spaces) ?? .min
        s["moveToManaged"] = moveToManaged?(connection, windows, space) ?? .min
        return (space, s)
    }

    func dismiss(space: UInt64) {
        _ = hide(connection, [NSNumber(value: space)] as CFArray)
        _ = destroy(connection, space)
    }
}
