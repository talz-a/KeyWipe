import SwiftUI
import ApplicationServices

@MainActor
class KeyboardCleaningViewModel: ObservableObject {
    @Published var isTrusted = AXIsProcessTrusted()
    @Published var isCleaning = false { didSet { updateEventTap() } }
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    
    func requestTrust() {
        let prompt = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options: NSDictionary = [prompt: true]
        AXIsProcessTrustedWithOptions(options)
    }
    
    func checkTrust() {
        isTrusted = AXIsProcessTrusted()
    }
    
    private func updateEventTap() {
        isCleaning ? startTap() : stopTap()
    }
    
    private var allKeyMask: CGEventMask {
        let codes = [CGEventType.keyDown, .keyUp, .flagsChanged]
            .map(\.rawValue) + [14]
        return CGEventMask(codes.reduce(0) { $0 | (1 << $1) })
    }
    
    private func startTap() {
        guard tap == nil else { return }
        guard let newTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: allKeyMask,
            callback: { _, _, _, _ in nil },
            userInfo: nil
        ) else { return }
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
        VStack(spacing: 12) {
            Text("KeyWipe")
                .font(.title2)
                .bold()
            if !vm.isTrusted {
                HStack(spacing: 12) {
                    Button(action: vm.requestTrust) {
                        Label("Request Access", systemImage: "lock.shield")
                    }
                    Button(action: vm.checkTrust) {
                        Label("Re-check", systemImage: "arrow.clockwise")
                    }
                }
            } else {
                VStack(spacing: 12) {
                    Toggle(isOn: $vm.isCleaning) {
                        Label(vm.isCleaning ? "Cleaning On" : "Cleaning Off",
                              systemImage: vm.isCleaning ? "lock.open.fill" : "lock.fill")
                    }
                    .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                    Button(action: { NSApplication.shared.terminate(nil) }) {
                        Label("Close App", systemImage: "xmark")
                    }
                }
            }
        }
        .padding(16)
    }
}

@main
struct KeyWipeApp: App {
    var body: some Scene {
        WindowGroup { ContentView() }
    }
}

#Preview {
    ContentView()
}
