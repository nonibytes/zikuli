//! Event Tracker for Virtual Tests
//!
//! Tracks X11 events (button press/release, motion, scroll) on test windows
//! to verify that input operations actually work, not just mouse position.
//!
//! Usage:
//!   var tracker = try EventTracker.init(allocator, conn);
//!   defer tracker.deinit();
//!
//!   tracker.trackWindow(window_id);
//!   // ... perform click ...
//!   try tracker.expectButtonPress(.left);

const std = @import("std");
const content_server = @import("content_server.zig");

// Use the same x11 import as content_server to avoid type mismatch
const x11 = content_server.x11;

/// Event types we track
pub const EventType = enum {
    button_press,
    button_release,
    motion,
    enter,
    leave,
};

/// Recorded event
pub const RecordedEvent = struct {
    event_type: EventType,
    button: u8, // 0 for non-button events
    x: i16,
    y: i16,
    timestamp: u32,
};

/// Event tracker for verifying X11 input events
pub const EventTracker = struct {
    allocator: std.mem.Allocator,
    conn: *x11.xcb_connection_t,
    tracked_windows: std.ArrayList(x11.xcb_window_t),
    events: std.ArrayList(RecordedEvent),

    pub fn init(allocator: std.mem.Allocator, conn: *x11.xcb_connection_t) EventTracker {
        return EventTracker{
            .allocator = allocator,
            .conn = conn,
            .tracked_windows = .empty,
            .events = .empty,
        };
    }

    pub fn deinit(self: *EventTracker) void {
        self.tracked_windows.deinit(self.allocator);
        self.events.deinit(self.allocator);
    }

    /// Register a window for event tracking
    pub fn trackWindow(self: *EventTracker, window_id: x11.xcb_window_t) !void {
        // Select events we want to receive
        const event_mask: u32 = x11.XCB_EVENT_MASK_BUTTON_PRESS |
            x11.XCB_EVENT_MASK_BUTTON_RELEASE |
            x11.XCB_EVENT_MASK_POINTER_MOTION |
            x11.XCB_EVENT_MASK_ENTER_WINDOW |
            x11.XCB_EVENT_MASK_LEAVE_WINDOW;

        _ = x11.xcb_change_window_attributes(
            self.conn,
            window_id,
            x11.XCB_CW_EVENT_MASK,
            &[_]u32{event_mask},
        );

        _ = x11.xcb_flush(self.conn);

        try self.tracked_windows.append(self.allocator, window_id);
    }

    /// Poll for pending events and record them
    pub fn pollEvents(self: *EventTracker) !void {
        while (true) {
            const event = x11.xcb_poll_for_event(self.conn);
            if (event == null) break;
            defer std.c.free(event);

            const response_type = event.*.response_type & 0x7f;

            switch (response_type) {
                x11.XCB_BUTTON_PRESS => {
                    const bp: *x11.xcb_button_press_event_t = @ptrCast(event);
                    try self.events.append(self.allocator, .{
                        .event_type = .button_press,
                        .button = bp.detail,
                        .x = bp.event_x,
                        .y = bp.event_y,
                        .timestamp = bp.time,
                    });
                },
                x11.XCB_BUTTON_RELEASE => {
                    const br: *x11.xcb_button_release_event_t = @ptrCast(event);
                    try self.events.append(self.allocator, .{
                        .event_type = .button_release,
                        .button = br.detail,
                        .x = br.event_x,
                        .y = br.event_y,
                        .timestamp = br.time,
                    });
                },
                x11.XCB_MOTION_NOTIFY => {
                    const mn: *x11.xcb_motion_notify_event_t = @ptrCast(event);
                    try self.events.append(self.allocator, .{
                        .event_type = .motion,
                        .button = 0,
                        .x = mn.event_x,
                        .y = mn.event_y,
                        .timestamp = mn.time,
                    });
                },
                x11.XCB_ENTER_NOTIFY => {
                    const en: *x11.xcb_enter_notify_event_t = @ptrCast(event);
                    try self.events.append(self.allocator, .{
                        .event_type = .enter,
                        .button = 0,
                        .x = en.event_x,
                        .y = en.event_y,
                        .timestamp = en.time,
                    });
                },
                x11.XCB_LEAVE_NOTIFY => {
                    const ln: *x11.xcb_leave_notify_event_t = @ptrCast(event);
                    try self.events.append(self.allocator, .{
                        .event_type = .leave,
                        .button = 0,
                        .x = ln.event_x,
                        .y = ln.event_y,
                        .timestamp = ln.time,
                    });
                },
                else => {},
            }
        }
    }

    /// Clear all recorded events
    pub fn clearEvents(self: *EventTracker) void {
        self.events.clearRetainingCapacity();
    }

    /// Count events of a specific type
    pub fn countEvents(self: *EventTracker, event_type: EventType) usize {
        var count: usize = 0;
        for (self.events.items) |e| {
            if (e.event_type == event_type) count += 1;
        }
        return count;
    }

    /// Count button press events for a specific button
    pub fn countButtonPresses(self: *EventTracker, button: u8) usize {
        var count: usize = 0;
        for (self.events.items) |e| {
            if (e.event_type == .button_press and e.button == button) count += 1;
        }
        return count;
    }

    /// Count button release events for a specific button
    pub fn countButtonReleases(self: *EventTracker, button: u8) usize {
        var count: usize = 0;
        for (self.events.items) |e| {
            if (e.event_type == .button_release and e.button == button) count += 1;
        }
        return count;
    }

    /// Check if a complete click (press + release) occurred
    pub fn hasClick(self: *EventTracker, button: u8) bool {
        return self.countButtonPresses(button) >= 1 and
            self.countButtonReleases(button) >= 1;
    }

    /// Check if a double-click occurred (2 press + 2 release)
    pub fn hasDoubleClick(self: *EventTracker, button: u8) bool {
        return self.countButtonPresses(button) >= 2 and
            self.countButtonReleases(button) >= 2;
    }

    /// Check for scroll events (button 4 = up, 5 = down)
    pub fn countScrollUp(self: *EventTracker) usize {
        // Scroll is button 4 press+release
        return self.countButtonPresses(4);
    }

    pub fn countScrollDown(self: *EventTracker) usize {
        // Scroll is button 5 press+release
        return self.countButtonPresses(5);
    }

    /// Check for motion events (useful for drag verification)
    pub fn hasMotion(self: *EventTracker) bool {
        return self.countEvents(.motion) > 0;
    }

    /// Verify a click occurred - returns error if not
    pub fn expectClick(self: *EventTracker, button: u8) !void {
        if (!self.hasClick(button)) {
            std.debug.print("Expected click with button {} but found {} presses, {} releases\n", .{
                button,
                self.countButtonPresses(button),
                self.countButtonReleases(button),
            });
            return error.ExpectedClickNotFound;
        }
    }

    /// Verify a double-click occurred
    pub fn expectDoubleClick(self: *EventTracker, button: u8) !void {
        if (!self.hasDoubleClick(button)) {
            std.debug.print("Expected double-click with button {} but found {} presses, {} releases\n", .{
                button,
                self.countButtonPresses(button),
                self.countButtonReleases(button),
            });
            return error.ExpectedDoubleClickNotFound;
        }
    }

    /// Verify scroll occurred
    pub fn expectScrollUp(self: *EventTracker, min_count: usize) !void {
        const count = self.countScrollUp();
        if (count < min_count) {
            std.debug.print("Expected at least {} scroll up events but found {}\n", .{ min_count, count });
            return error.ExpectedScrollNotFound;
        }
    }

    pub fn expectScrollDown(self: *EventTracker, min_count: usize) !void {
        const count = self.countScrollDown();
        if (count < min_count) {
            std.debug.print("Expected at least {} scroll down events but found {}\n", .{ min_count, count });
            return error.ExpectedScrollNotFound;
        }
    }

    /// Verify motion occurred (for drag tests)
    pub fn expectMotion(self: *EventTracker) !void {
        if (!self.hasMotion()) {
            std.debug.print("Expected motion events but found none\n", .{});
            return error.ExpectedMotionNotFound;
        }
    }

    /// Verify a drag occurred (button down, motion, button up)
    pub fn expectDrag(self: *EventTracker, button: u8) !void {
        // Need at least: 1 press, some motion, 1 release
        // And the order should be: press before release
        var found_press = false;
        var found_motion_after_press = false;
        var found_release_after_motion = false;

        for (self.events.items) |e| {
            if (e.event_type == .button_press and e.button == button) {
                found_press = true;
            } else if (e.event_type == .motion and found_press) {
                found_motion_after_press = true;
            } else if (e.event_type == .button_release and e.button == button and found_motion_after_press) {
                found_release_after_motion = true;
            }
        }

        if (!found_press) {
            std.debug.print("Drag verification failed: no button {} press found\n", .{button});
            return error.ExpectedDragNotFound;
        }
        if (!found_motion_after_press) {
            std.debug.print("Drag verification failed: no motion after button press\n", .{});
            return error.ExpectedDragNotFound;
        }
        if (!found_release_after_motion) {
            std.debug.print("Drag verification failed: no button release after motion\n", .{});
            return error.ExpectedDragNotFound;
        }
    }

    /// Print all recorded events (for debugging)
    pub fn printEvents(self: *EventTracker) void {
        std.debug.print("\n=== Recorded Events ({}) ===\n", .{self.events.items.len});
        for (self.events.items, 0..) |e, i| {
            const type_str = switch (e.event_type) {
                .button_press => "PRESS",
                .button_release => "RELEASE",
                .motion => "MOTION",
                .enter => "ENTER",
                .leave => "LEAVE",
            };
            std.debug.print("[{}] {} button={} pos=({},{})\n", .{ i, type_str, e.button, e.x, e.y });
        }
        std.debug.print("============================\n", .{});
    }
};

pub const EventTrackerError = error{
    ExpectedClickNotFound,
    ExpectedDoubleClickNotFound,
    ExpectedScrollNotFound,
    ExpectedMotionNotFound,
    ExpectedDragNotFound,
};
