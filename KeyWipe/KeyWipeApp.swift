import SwiftUI

@main
struct KeyWipeApp: App {

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    startKeyCapture()
                }
        }
    }
}

func startKeyCapture() {
    guard AXIsProcessTrusted() else {
        print("App is not trusted. Please grant Accessibility permissions.")
        return
    }

    guard let tap = CGEvent.tapCreate(
        tap: .cgSessionEventTap,
        place: .headInsertEventTap,
        options: .defaultTap,
        eventsOfInterest: CGEventMask(1 << CGEventType.keyDown.rawValue),
        callback: handleKeyDown,
        userInfo: nil
    ) else {
        print("Failed to create event tap.")
        return
    }

    installEventTap(tap)

    print("Key capture started.")
}

private var retainedTap: CFMachPort?

func installEventTap(_ tap: CFMachPort) {
    retainedTap = tap
    let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
    CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
    CGEvent.tapEnable(tap: tap, enable: true)
}

func handleKeyDown(
    proxy: CGEventTapProxy,
    type: CGEventType,
    cgEvent: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {

    guard let nsEvent = NSEvent(cgEvent: cgEvent),
          nsEvent.type == .keyDown else {
        return Unmanaged.passUnretained(cgEvent)
    }

    let cmdPressed = nsEvent.modifierFlags.contains(.command)
    let pressedChar = nsEvent.charactersIgnoringModifiers?.lowercased() ?? ""

    if cmdPressed && pressedChar == "h" {
        print("Command+H pressed")
        return nil
    }

    return Unmanaged.passUnretained(cgEvent)
}
