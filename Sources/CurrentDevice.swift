import Foundation
#if os(watchOS)
import WatchKit
#endif
#if canImport(UIKit)
import UIKit
#endif

public extension Device {
    /// An object representing the current device this software is running on.
    static var current: CurrentDevice = ActualHardwareDevice() // singleton representing the current device but separated so that we can replace or mock
}

/// The thermal state of the system.
public enum ThermalState {
    /// The thermal state is within normal limits.
    case nominal
    /// The thermal state is slightly elevated.
    case fair
    /// The thermal state is high.
    case serious
    /// The thermal state is significantly impacting the performance of the system and the device needs to cool down.
    case critical
}

#if canImport(Observable)
    @Observable
#endif
public protocol CurrentDevice: DeviceType {
    /// Returns `true` if running on the simulator vs actual device.
    var isSimulator: Bool { get }
    /// Returns `true` if running in Swift Playgrounds.
    var isPlayground: Bool { get }
    /// Returns `true` if running in an XCode or Swift Playgrounds #Preview macro.
    var isPreview: Bool { get }
    /// Returns `true` if NOT running in preview, playground, or simulator.
    var isRealDevice: Bool { get }
    /// Returns `true` if Built for iPad mode not a native mode (for macOS and visionOS)
    var isDesignedForiPad: Bool { get }
    /// Gets the identifier from the system, such as "iPhone7,1".
    var identifier: String { get }
    /// Returns a battery object that can be monitored or queried for live data if a battery is present on the device.  If not, this will return `nil`.
    var battery: DeviceBattery? { get }
    /// Returns if the screen is zoomed in.
    var isZoomed: Bool? { get }
    /// Returns the screen orientation if applicable or `nil`
    var screenOrientation: Screen.Orientation? { get }
    
    /// The name identifying the device (e.g. "Dennis' iPhone").
    /// As of iOS 16, this will return a generic String like "iPhone", unless your app has additional entitlements.
    /// See the follwing link for more information: https://developer.apple.com/documentation/uikit/uidevice/1620015-name
    var name: String { get } // should be automatic since DeviceType defines name property.
    /// The name of the operating system running on the device represented by the receiver (e.g. "iOS" or "tvOS").
    var systemName: String { get }
    /// The current version of the operating system (e.g. 8.4 or 9.2).
    var systemVersion: String { get }
    /// The model of the device (e.g. "iPhone" or "iPod Touch").
    var model: String { get }
    /// The model of the device as a localized string.
    var localizedModel: String { get }
    
    
    /// True when a Guided Access session is currently active; otherwise, false.
    var isGuidedAccessSessionActive: Bool { get }
    /// The brightness level of the screen.
    var screenBrightness: Int { get }
    
    /// Returns the current thermal state of the system (or nil if could not be determined)
    var thermalState: ThermalState? { get }
    
    /// The volume’s total capacity in bytes.
    var volumeTotalCapacity: Int? { get }
    /// The volume’s available capacity in bytes.
    var volumeAvailableCapacity: Int? { get }
    
    /// The volume’s available capacity in bytes for storing important resources.
    var volumeAvailableCapacityForImportantUsage: Int64? { get }
    
    /// The volume’s available capacity in bytes for storing nonessential resources.
    var volumeAvailableCapacityForOpportunisticUsage: Int64? { get }
    
    /// All volumes capacity information in bytes.
    var volumes: [URLResourceKey: Int64]? { get }
    
    /// Ability to change/get the idle timeout setting.
    var isIdleTimerDisabled: Bool { get set }
    /// When called, will automatically start monitoring the battery state to disable idle timer when plugged in.
    func disableIdleTimerWhenPluggedIn()
}

// this is internal because it shouldn't be directly needed outside the framework.  Everything is exposed via CurrentDevice protocol.
// TODO: should this be a final class?
class ActualHardwareDevice: CurrentDevice {
    var device: Device
    
    init() {
        device = Device(identifier: identifier)
    }
    
    /// Description (includes current identifier since device might have multiple).
    public var description: String {
        return "\(device.description) (\(identifier))"
    }
    
    /// Returns `true` if running on the simulator vs actual device.
    public var isSimulator: Bool {
#if targetEnvironment(simulator)
        // your simulator code
        return true
#else
        // your real device code
        return false
#endif
    }
    
    // In macOS Playgrounds Preview: swift-playgrounds-dev-previews.swift-playgrounds-app.hdqfptjlmwifrrakcettacbhdkhn.501.KuditFramework
    // In macOS Playgrounds Running: swift-playgrounds-dev-run.swift-playgrounds-app.hdqfptjlmwifrrakcettacbhdkhn.501.KuditFrameworksApp
    // In iPad Playgrounds Preview: swift-playgrounds-dev-previews.swift-playgrounds-app.agxhnwfqkxciovauscbmuhqswxkm.501.KuditFramework
    // In iPad Playgrounds Running: swift-playgrounds-dev-run.swift-playgrounds-app.agxhnwfqkxciovauscbmuhqswxkm.501.KuditFrameworksApp
    /// Returns `true` if running in Swift Playgrounds.
    var isPlayground: Bool {
        //print("Testing inPlayground: Bundles: \(Bundle.allBundles.map { $0.bundleIdentifier }.description)")
        if Bundle.allBundles.contains(where: { ($0.bundleIdentifier ?? "").contains("swift-playgrounds") }) {
            //print("in playground")
            return true
        } else {
            //print("not in playground")
            return false
        }
    }
    
    /// Returns `true` if running in an XCode or Swift Playgrounds #Preview macro.
    var isPreview: Bool {
        // TODO: Verify this works in Swift Playgrounds and not just XCode
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
    
    /// Returns `true` if NOT running in preview, playground, or simulator.
    var isRealDevice: Bool {
        return !isPreview && !isPlayground && !isSimulator
    }
    
    /// Returns `true` if Built for iPad mode not a native mode (for macOS and visionOS)
    var isDesignedForiPad: Bool {
        // Check for mismatch between systemName and expected idiom based on identifier.
        if Device.current.idiom == .vision && Device.current.systemName == "iPadOS" {
            return true
        }
        // Note: this will be "false" under Catalyst which is what we want.
        if #available(watchOS 7.0, *) {
            return ProcessInfo().isiOSAppOnMac
        } else {
            // Fallback on earlier versions
            return false
        }
    }

    /// Gets the identifier from the system, such as "iPhone7,1".
    var identifier: String = {
#if os(macOS)
        let service = IOServiceGetMatchingService(kIOMasterPortDefault,
                                                  IOServiceMatching("IOPlatformExpertDevice"))
        var modelIdentifier: String?
        if let modelData = IORegistryEntryCreateCFProperty(service, "model" as CFString, kCFAllocatorDefault, 0).takeRetainedValue() as? Data {
            modelIdentifier = String(data: modelData, encoding: .utf8)?.trimmingCharacters(in: .controlCharacters)
        }

        IOObjectRelease(service)
        return modelIdentifier ?? "UnknownIdentifier"
#elseif targetEnvironment(macCatalyst)
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        
        var modelIdentifier: [CChar] = Array(repeating: 0, count: size)
        sysctlbyname("hw.model", &modelIdentifier, &size, nil, 0)
        
        return String(cString: modelIdentifier)
#else
        //        print(ProcessInfo().environment)
        if let identifier = ProcessInfo().environment["SIMULATOR_MODEL_IDENTIFIER"] {
            // machine value is likely just arm64 so return the simulator identifier
            return identifier
        }
        var systemInfo = utsname()
        uname(&systemInfo)
        let mirror = Mirror(reflecting: systemInfo.machine)
        
        let identifier = mirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier
#endif
    }()
    
    /// Returns a battery object that can be monitored or queried for live data if a battery is present on the device.  If not, this will return nil.
    var battery: DeviceBattery? {
        if device.has(.battery) {
            return DeviceBattery.current
        }
        return nil
    }
    
    /// Returns if the screen is zoomed in.
    public var isZoomed: Bool? {
#if os(iOS) && !os(visionOS)
        if Int(UIScreen.main.scale.rounded()) == 3 {
            // Plus-sized
            return UIScreen.main.nativeScale > 2.7 && UIScreen.main.nativeScale < 3
        } else {
            return UIScreen.main.nativeScale > UIScreen.main.scale
        }
#else
        return nil
#endif
    }
    
    var screenOrientation: Screen.Orientation? {
#if os(iOS) && !os(visionOS)
        if UIDevice.current.orientation.isLandscape {
            return .landscape
        } else {
            return .portrait
        }
#else
        return nil
#endif
    }
     
    // MARK: - Characteristic Device Strings
    
    // TODO: Make all the below legacy deprecated DeviceKitBridge implementations and instead provide default values so these are not optional to make it easier to include in projects without having to test for nil?  Have default values that can be tested against in case we need to know that?
    
    /// The name identifying the device (e.g. "Dennis' iPhone").
    /// As of iOS 16, this will return a generic String like "iPhone", unless your app has additional entitlements.
    /// See the follwing link for more information: https://developer.apple.com/documentation/uikit/uidevice/1620015-name
    public var name: String {
#if os(watchOS)
        return WKInterfaceDevice.current().name
#elseif canImport(UIKit)
        return UIDevice.current.name
#else
        return .unknown
#endif
    }
    
    /// The name of the operating system running on the device represented by the receiver (e.g. "iOS" or "tvOS").
    public var systemName: String {
#if os(watchOS)
        return WKInterfaceDevice.current().systemName
#elseif os(iOS)
        let systemName = UIDevice.current.systemName
        if idiom == .pad, #available(iOS 13, *), systemName == "iOS" {
            return "iPadOS"
        } else {
            return systemName
        }
#elseif canImport(UIKit)
        return UIDevice.current.systemName
#else
        return .unknown
#endif
    }
    
    /// The current version of the operating system (e.g. 8.4 or 9.2).
    public var systemVersion: String {
#if os(watchOS)
        return WKInterfaceDevice.current().systemVersion
#elseif canImport(UIKit)
        return UIDevice.current.systemVersion
#else
        return "0.0"
#endif
    }
    
    /// The model of the device (e.g. "iPhone" or "iPod Touch").
    public var model: String {
#if os(watchOS)
        return WKInterfaceDevice.current().model
#elseif canImport(UIKit)
        return UIDevice.current.model
#else
        return .unknown
#endif
    }
    
    /// The model of the device as a localized string.
    public var localizedModel: String {
#if os(watchOS)
        return WKInterfaceDevice.current().localizedModel
#elseif canImport(UIKit)
        return UIDevice.current.localizedModel
#else
        return .unknown
#endif
    }
    
    // MARK: - Additional features
    
    /// True when a Guided Access session is currently active; otherwise, false.
    public var isGuidedAccessSessionActive: Bool {
#if os(iOS)
#if swift(>=4.2)
        return UIAccessibility.isGuidedAccessEnabled
#else
        return UIAccessibilityIsGuidedAccessEnabled()
#endif
#else
        return false
#endif
    }
    
    /// The brightness level of the screen (between 0 and 100).  Only supported on iOS and macCatalyst.  Returns -1 if not supported.
    public var screenBrightness: Int {
#if os(iOS) || targetEnvironment(macCatalyst)
        return Int(UIScreen.main.brightness * 100)
#else
        return -1
#endif
    }
    
    // MARK: ThermalState
    /// Returns the current thermal state of the system (or nil if could not be determined)
    public var thermalState: ThermalState? {
        if #available(iOS 11.0, watchOS 4.0, macOS 10.10.3, tvOS 11.0, visionOS 1.0, macCatalyst 13.1, *) {
            switch ProcessInfo().thermalState {
            case .nominal:
                return .nominal
            case .fair:
                return .fair
            case .serious:
                return .serious
            case .critical:
                return .critical
            @unknown default:
                return nil
            }
        } else {
            return nil
        }
    }
    
    // MARK: DiskSpace
    /// Return the root url
    ///
    /// - returns: the NSHomeDirectory() url
    private let rootURL = URL(fileURLWithPath: NSHomeDirectory())
    
    /// The volume’s total capacity in bytes.
    public var volumeTotalCapacity: Int? {
        return (try? rootURL.resourceValues(forKeys: [.volumeTotalCapacityKey]))?.volumeTotalCapacity
    }
    
    /// The volume’s available capacity in bytes.
    public var volumeAvailableCapacity: Int? {
        return (try? rootURL.resourceValues(forKeys: [.volumeAvailableCapacityKey]))?.volumeAvailableCapacity
    }
    
    /// The volume’s available capacity in bytes for storing important resources.
    public var volumeAvailableCapacityForImportantUsage: Int64? {
#if os(tvOS) || os(watchOS)
            return nil
#else
        if #available(iOS 11.0, *) {
            return (try? rootURL.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]))?.volumeAvailableCapacityForImportantUsage
        } else {
            return nil
        }
#endif
    }
    
    /// The volume’s available capacity in bytes for storing nonessential resources.
    public var volumeAvailableCapacityForOpportunisticUsage: Int64? {
#if os(tvOS) || os(watchOS)
            return nil
#else
        if #available(iOS 11.0, *) {
            return (try? rootURL.resourceValues(forKeys: [.volumeAvailableCapacityForOpportunisticUsageKey]))?.volumeAvailableCapacityForOpportunisticUsage
        } else {
            return nil
        }
#endif
    }
    
    /// All volumes capacity information in bytes.
    public var volumes: [URLResourceKey: Int64]? {
#if os(tvOS) || os(watchOS)
            return nil
#else
        if #available(iOS 11.0, *) {
            do {
                let values = try rootURL.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey,
                                                                  .volumeAvailableCapacityKey,
                                                                  .volumeAvailableCapacityForOpportunisticUsageKey,
                                                                  .volumeTotalCapacityKey
                ])
                return values.allValues.mapValues {
                    if let int = $0 as? Int64 {
                        return int
                    }
                    if let int = $0 as? Int {
                        return Int64(int)
                    }
                    return 0
                }
            } catch {
                return nil
            }
        } else {
            return nil
        }
#endif
    }
    
    private var _isIdleTimerDisabled = false
    /// Ability to change/get the idle timeout setting.
    var isIdleTimerDisabled: Bool {
        get {
            _isIdleTimerDisabled
        }
        set {
            _isIdleTimerDisabled = newValue
            _disableIdleTimer(newValue)
        }
    }
    /// Actually disable the idle timer
    private func _disableIdleTimer(_ disabled: Bool = true) {
#if canImport(UIKit) && !os(watchOS)
        UIApplication.shared.isIdleTimerDisabled = disabled
#endif        
    }
    private var _disableIdleTimerWhenPluggedIn = false
    /// Automatically start monitoring the battery state to disable idle timer when plugged in and re-enable when unplugged.
    func disableIdleTimerWhenPluggedIn() {
        guard !_disableIdleTimerWhenPluggedIn else {
            // atttempting to disable idle timer multiple times.  This should only be set on launch.
            print("WARNING: attempting to disable idle timer when this has already been set.  You should only call this function once (probably at launch or main init).  Set a breakpoint to see why there's a duplicate call.")
            return
        }
        guard let battery = self.battery else {
            // attempting to disable idle timer when plugged in when we don't even have a battery.  Just ignore.
            return
        }
        _disableIdleTimerWhenPluggedIn = true // so we only do this once in case called multiple times.
        if battery.isPluggedIn {
            _disableIdleTimer()
        }
        battery.add(monitor: { battery in
            // unnecessary when battery level changes, but it shouldn't really be much to repeat.
            self._disableIdleTimer(battery.isPluggedIn ? true : self._isIdleTimerDisabled)
                // don't disable timer when unplugged unless we've manually set it to always be disabled.  So when unplugged, re-enable idle timer unless we've set it to always disabled.
        })
    }
}
