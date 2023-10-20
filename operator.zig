const operator_api = @cImport({
    @cInclude("operator/operator_api.h");
});
const std = @import("std");
const panic = @import("std").debug.panic;
const print = @import("std").debug.print;

var buffer: [1024 * 1024]u8 = undefined;
// var fba = std.heap.FixedBufferAllocator.init(&buffer);
// const allocator = fba.allocator();
const allocator = std.heap.page_allocator;

export fn dora_init_operator() callconv(.C) operator_api.DoraInitResult_t {
    const memory = allocator.alloc(u8, 1) catch @panic("alloc failed\r\n");
    memory[0] = 0;

    const r = operator_api.DoraInitResult_t{
        .result = operator_api.DoraResult_t{ .@"error" = .{
            .ptr = null,
            .len = 0,
            .cap = 0,
        } },
        .operator_context = memory.ptr,
    };

    return r;
}

export fn dora_drop_operator(operator_context: ?*anyopaque) operator_api.DoraResult_t {
    if (operator_context) |p| {
        allocator.free(@as(*[1]u8, @ptrCast(p)));
    }

    const r = operator_api.DoraResult_t{ .@"error" = .{
        .ptr = null,
        .len = 0,
        .cap = 0,
    } };

    return r;
}

export fn dora_on_event(event: [*c]const operator_api.RawEvent_t, send_output: [*c]const operator_api.SendOutput_t, operator_context: ?*anyopaque) operator_api.OnEventResult_t {
    var counter = @as(*u8, @ptrCast((operator_context orelse @panic("null operator_context"))));
    if (event[0].input) |input| {
        const id = allocator.dupe(u8, @as([*]u8, @ptrCast(input[0].id.ptr))[0..input[0].id.len]) catch @panic("alloc id failed\r\n");
        defer allocator.free(id);

        if (std.mem.eql(u8, id, "message")) {
            const data = allocator.dupe(u8, @as([*]u8, @ptrCast(input[0].data.ptr))[0..input[0].data.len]) catch @panic("alloc data failed\r\n");
            defer allocator.free(data);

            counter.* += 1;
            print("zig operator received message `{s}`, counter: {}\r\n", .{ data, counter.* });

            const out_id_heap = allocator.dupeZ(u8, "counter") catch @panic("alloc out_id_heap failed\r\n");
            // const data_alloc_size: usize = 100;
            // _ = data_alloc_size;
            // const out_data = allocator.alloc(u8, data_alloc_size) catch panic("alloc out_data failed, len {}\r\n", .{data_alloc_size});
            var out_data_s: [100]u8 = undefined;
            const count_s = std.fmt.bufPrint(&out_data_s, "The current counter value is {}", .{counter.*}) catch @panic("alloc out_data failed\r\n");
            const count = allocator.dupeZ(u8, count_s) catch @panic("alloc count failed\r\n");

            std.debug.assert(count.len < 100);

            const output = operator_api.Output_t{
                .id = .{
                    .ptr = out_id_heap.ptr,
                    .len = out_id_heap.len,
                    .cap = out_id_heap.len + 1,
                },
                .data = .{
                    .ptr = count.ptr,
                    .len = count.len,
                    .cap = count.len + 1,
                },
                .metadata = .{ .open_telemetry_context = .{
                    .ptr = null,
                    .len = 0,
                    .cap = 0,
                } },
            };

            // print("here\r\n", .{});
            var res = send_output[0].send_output.call.?(send_output[0].send_output.env_ptr, output);
            _ = res;
            // print("here1\r\n", .{});

            // return operator_api.OnEventResult_t{ .result = res, .status = operator_api.DORA_STATUS_CONTINUE };
            return operator_api.OnEventResult_t{
                .result = operator_api.DoraResult_t{ .@"error" = .{
                    .ptr = null,
                    .len = 0,
                    .cap = 0,
                } },
                .status = operator_api.DORA_STATUS_CONTINUE,
            };
        }
    }

    if (event[0].stop) {
        print("zig operator received stop event\n", .{});
    }

    return operator_api.OnEventResult_t{
        .result = operator_api.DoraResult_t{ .@"error" = .{
            .ptr = null,
            .len = 0,
            .cap = 0,
        } },
        .status = operator_api.DORA_STATUS_CONTINUE,
    };
}
