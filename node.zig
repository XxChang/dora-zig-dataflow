const node_api = @cImport({
    @cInclude("node/node_api.h");
});
const std = @import("std");
const print = @import("std").debug.print;
const panic = @import("std").debug.panic;
const assert = @import("std").debug.assert;

pub fn main() u8 {
    print("[zig node] Hello World\n", .{});

    const dora_context = node_api.init_dora_context_from_env() orelse {
        panic("failed to init dora context\n", .{});
    };

    print("[zig node] dora context initialized\n", .{});

    var i: u8 = 0;
    while (i < 3000) : (i += 1) {
        var event = node_api.dora_next_event(dora_context) orelse {
            print("[zig node] ERROR: unexpected end of event\n", .{});
            return 1;
        };

        const ty = node_api.read_dora_event_type(event);

        switch (ty) {
            node_api.DoraEventType_Input => {
                var data_len: usize = undefined;
                var data: [*c]u8 = undefined;
                node_api.read_dora_input_data(event, @as([*c][*c]u8, @ptrCast(&data)), &data_len);

                assert(data_len == 0);

                var out_id_conent: [50]u8 = undefined;
                const out_id = std.fmt.bufPrint(&out_id_conent, "message", .{}) catch {
                    return 1;
                };

                var content: [50]u8 = undefined;
                const out_data = std.fmt.bufPrint(&content, "loop iteration {}", .{i}) catch {
                    return 1;
                };

                _ = node_api.dora_send_output(dora_context, out_id.ptr, out_id.len, out_data.ptr, out_data.len);
            },
            node_api.DoraEventType_Stop => {
                print("[zig node] received stop event\n", .{});
            },
            else => {
                print("[zig node] received unexpected event: {}\n", .{ty});
            },
        }

        node_api.free_dora_event(event);
    }

    print("[zig node] received 10 events\n", .{});

    node_api.free_dora_context(dora_context);

    print("[zig node] finished successfully\n", .{});

    return 0;
}
