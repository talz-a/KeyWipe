import AppKit
import CoreGraphics
import SwiftUI

@Observable
class KeyboardCleaner {
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
                x: mouseLocation.x,
                y: convertedY - 100
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
    @State private var vm = KeyboardCleaner()
    @State private var imageScaled = false

    var body: some View {
        VStack(spacing: 16) {
            Image("AppIconLarge")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .accessibilityHidden(true)
                .padding(.top, 20)
                .scaleEffect(imageScaled ? 1.0 : 0.6)
                .animation(
                    .spring(response: 0.5, dampingFraction: 0.6),
                    value: imageScaled
                )
                .onAppear {
                    imageScaled = true
                }
            Text("KeyWipe")
                .font(.system(.largeTitle, design: .rounded).bold())
            ZStack {
                VStack(spacing: 20) {
                    if !vm.isTrusted {
                        Button(
                            action: {
                                vm.requestTrust()
                            },
                            label: {
                                Text("Start")
                                    .font(.system(size: 20, design: .rounded))
                                    .padding(.horizontal, 10)
                            }
                        )
                        .buttonStyle(.bordered)
                        .clipShape(Capsule())
                    } else {
                        Toggle(isOn: $vm.isCleaning) {
                            Label(
                                vm.isCleaning
                                    ? "Cleaning On" : "Cleaning Off",
                                systemImage: vm.isCleaning
                                    ? "lock.open.fill" : "lock.fill"
                            )
                        }
                        .toggleStyle(.switch)
                        .frame(maxWidth: .infinity, alignment: .center)
                        Button(
                            action: {
                                NSApplication.shared.terminate(nil)
                            },
                            label: {
                                Label {
                                    Text("Quit App")
                                        .font(
                                            .system(size: 15, design: .rounded)
                                        )
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 2)
                                } icon: {
                                    Image(systemName: "xmark")
                                }
                            }
                        )
                        .buttonStyle(.bordered)
                        .clipShape(Capsule())
                        .keyboardShortcut(.cancelAction)
                    }
                }
                .frame(width: 250)
            }
            .frame(maxWidth: 200, maxHeight: 200)
            .padding(15)
        }
        .padding()
        .frame(width: 250, height: 300)
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

#Preview {
    ContentView()
}
