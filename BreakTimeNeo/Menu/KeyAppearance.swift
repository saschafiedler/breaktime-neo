import AppKit
import ObjectiveC

/// Makes the popover draw its controls as active (blue switch, coloured
/// slider) even when it does not have the keyboard.
///
/// The popover opens by itself before a break and must not take the keyboard
/// away from the app the user is typing in. AppKit then draws it as inactive,
/// so it looks different from the popover opened by a click. AppKit decides
/// this through the window's `hasKeyAppearance`, which is not public API.
/// The popover's own window class (used only for popovers, and the app has
/// just one) answers it with yes. If a future macOS drops the method, the
/// popover simply looks inactive again; nothing else changes.
enum KeyAppearance {
    private static let selector = NSSelectorFromString("hasKeyAppearance")
    private static var patchedClasses: Set<ObjectIdentifier> = []

    static func force(onPopoverWindow window: NSWindow) {
        guard window.responds(to: selector), var windowClass = object_getClass(window) else { return }
        // SwiftUI observes the window via KVO, which puts a generated
        // subclass in between; patch the real class underneath.
        if NSStringFromClass(windowClass).hasPrefix("NSKVONotifying_"), let real = class_getSuperclass(windowClass) {
            windowClass = real
        }
        // Never touch the shared base classes: every window would look active.
        guard windowClass != NSWindow.self, windowClass != NSPanel.self else { return }
        if !patchedClasses.contains(ObjectIdentifier(windowClass)) {
            let alwaysYes: @convention(block) (AnyObject) -> Bool = { _ in true }
            class_replaceMethod(windowClass, selector, imp_implementationWithBlock(alwaysYes), "c@:")
            patchedClasses.insert(ObjectIdentifier(windowClass))
        }
        redraw(window.contentView)
    }

    private static func redraw(_ view: NSView?) {
        guard let view else { return }
        view.needsDisplay = true
        view.subviews.forEach(redraw)
    }
}
