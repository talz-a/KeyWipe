import AppKit
import CoreGraphics
import SwiftUI

@Observable
class KeyboardCleaningViewModel {
    var isTrusted = AXIsProcessTrusted()
    var isCleaning = false {
        didSet { updateEventTap() }
    }

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    private var allKeyMask: CGEventMask {
        let codes =
            [CGEventType.keyDown, .keyUp, .flagsChanged].map(\.rawValue) + [14]
        return CGEventMask(codes.reduce(0) { $0 | (1 << $1) })
    }

    func requestTrust() {
        let prompt = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options: NSDictionary = [prompt: true]
        AXIsProcessTrustedWithOptions(options)
    }

    func refreshTrustStatus() {
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
            let newMouseLocation = CGPoint(
                x: mouseLocation.x - 200,
                y: convertedY
            )
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
        guard let existingTap = tap, let existingSource = runLoopSource else {
            return
        }
        CGEvent.tapEnable(tap: existingTap, enable: false)
        CFRunLoopRemoveSource(CFRunLoopGetMain(), existingSource, .commonModes)
        CFMachPortInvalidate(existingTap)
        tap = nil
        runLoopSource = nil
    }
}

struct ContentView: View {
    @State private var vm = KeyboardCleaningViewModel()

    var body: some View {
        VStack(spacing: 24) {
            Text("KeyWipe")
                .font(.largeTitle.bold())
            HStack(spacing: 24) {
                Image("AppIconLarge")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .accessibilityHidden(true)
                if !vm.isTrusted {
                    VStack(spacing: 16) {
                        Button {
                            vm.requestTrust()
                        } label: {
                            Label(
                                "Request Accessibility Access",
                                systemImage: "lock.shield"
                            )
                        }
                        Button(
                            "Re-check Access",
                            systemImage: "arrow.clockwise",
                            action: vm.refreshTrustStatus
                        )
                    }
                } else {
                    VStack(spacing: 16) {
                        Toggle(isOn: $vm.isCleaning) {
                            Label(
                                vm.isCleaning
                                    ? "Cleaning Mode On" : "Cleaning Mode Off",
                                systemImage: vm.isCleaning
                                    ? "lock.open.fill" : "lock.fill"
                            )
                        }
                        .toggleStyle(.switch)
                        .padding(.top, 8)
                        Button("Quit App", systemImage: "xmark") {
                            NSApplication.shared.terminate(nil)
                        }
                        .keyboardShortcut(.cancelAction)
                    }
                }
            }
            .padding(24)
        }
        .padding()
        .frame(width: 500, height: 200)
        .task {
            vm.refreshTrustStatus()
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: NSApplication.didBecomeActiveNotification
            )
        ) { _ in
            vm.refreshTrustStatus()
        }

    }
}

@main
struct KeyWipeApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowLevel(.floating)
        .windowResizability(.contentSize)
    }
}
