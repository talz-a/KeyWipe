import SwiftUI
import CoreGraphics
import AppKit

@MainActor
class KeyboardCleaningViewModel: ObservableObject {
    @Published var isTrusted = AXIsProcessTrusted()
    @Published var isCleaning = false { didSet { updateEventTap() } }

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var allKeyMask: CGEventMask {
        let codes =
            [CGEventType.keyDown, .keyUp, .flagsChanged]
            .map(\.rawValue) + [14]
        return CGEventMask(codes.reduce(0) { $0 | (1 << $1) })
    }

    func requestTrust() {
        let prompt = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options: NSDictionary = [prompt: true]
        AXIsProcessTrustedWithOptions(options)
    }
    
    func checkTrust() {
        isTrusted = AXIsProcessTrusted()
    }

    private func updateEventTap() {
        if isCleaning {
            startTap()
            moveMouse()
        } else {
            stopTap()
        }
    }
    
    private func moveMouse() {
        let mouseLocation = NSEvent.mouseLocation
        if let screen = NSScreen.main {
            let screenHeight = screen.frame.height
            let convertedY = screenHeight - mouseLocation.y
            let newMouseLocation = CGPoint(x: mouseLocation.x - 200, y: convertedY)
            CGDisplayMoveCursorToPoint(CGMainDisplayID(), newMouseLocation)
        }
    }
    
    private func startTap() {
        guard tap == nil else { return }
        guard
            let newTap = CGEvent.tapCreate(
                tap: .cgSessionEventTap,
                place: .headInsertEventTap,
                options: .defaultTap,
                eventsOfInterest: allKeyMask,
                callback: { _, _, _, _ in nil },
                userInfo: nil
            )
        else { return }
        tap = newTap
        runLoopSource = CFMachPortCreateRunLoopSource(nil, newTap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: newTap, enable: true)
    }

    private func stopTap() {
        guard let existingTap = tap,
            let existingSource = runLoopSource
        else { return }
        CGEvent.tapEnable(tap: existingTap, enable: false)
        CFRunLoopRemoveSource(CFRunLoopGetMain(), existingSource, .commonModes)
        CFMachPortInvalidate(existingTap)
        tap = nil
        runLoopSource = nil
    }
}

struct ContentView: View {
    @StateObject private var vm = KeyboardCleaningViewModel()

    var body: some View {
        VStack(spacing: 24) {
            Text("KeyWipe")
                .font(.title)
                .bold()
            HStack(alignment: .center, spacing: 24) {
                Image("AppIconLarge")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                if !vm.isTrusted {
                    VStack(spacing: 16) {
                        Button(action: vm.requestTrust) {
                            Label("Request Access", systemImage: "lock.shield")
                                .frame(maxWidth: .infinity)
                        }
                        Button(action: vm.checkTrust) {
                            Label("Re-check", systemImage: "arrow.clockwise")
                                .frame(maxWidth: .infinity)
                        }
                    }
                } else {
                    VStack(spacing: 16) {
                        Toggle(isOn: $vm.isCleaning) {
                            Label(
                                vm.isCleaning ? "Cleaning On" : "Cleaning Off",
                                systemImage: vm.isCleaning
                                    ? "lock.open.fill" : "lock.fill"
                            )
                            .font(.title2)
                            .frame(minWidth: 160, alignment: .leading)
                        }
                        .toggleStyle(SwitchToggleStyle(tint: .blue))
                        .padding()
                        Button(action: { NSApplication.shared.terminate(nil) })
                        {
                            Label("Close App", systemImage: "xmark")
                        }
                    }
                }
            }
            .padding(24)
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(
        _ sender: NSApplication
    ) -> Bool {
        return true
    }
}

@main
struct KeyWipeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView().frame(width: 500, height: 200)
        }
        .windowLevel(.floating)
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }
}

#Preview {
    ContentView()
}
