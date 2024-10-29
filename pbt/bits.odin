package pbt

import "core:math/rand"

STREAM_SIZE :: 32

Group_Info :: struct {
    begin: int,
    end: int,
    //label: string,
}

Recorded_Bits :: struct {
    data:   [dynamic]u64,
    groups: [dynamic]Group_Info,
}

Group_Id :: distinct int

// TODO: Add support for groups
begin_group :: proc(recorded: ^Recorded_Bits, label: string) -> Group_Id {
    // append(&recorded.groups, Group_Info {
    //     begin = len(recorded.data),
    //     //label = label,
    // })

    return Group_Id(len(recorded.groups) - 1)
}

end_group :: proc(recorded: ^Recorded_Bits, gid: Group_Id) {
    //recorded.groups[gid].end = len(recorded.data)
}

Buffered_Bit_Stream :: struct {
    buffer: [dynamic]u64,
    recorded: Recorded_Bits,
}

Random_Bit_Stream :: struct {
    recorded: Recorded_Bits,
}

Bit_Stream :: union {
    Buffered_Bit_Stream,
    Random_Bit_Stream,
}

get_recorded :: proc(stream: Bit_Stream) -> Recorded_Bits {
    bits: Recorded_Bits
    switch s in stream {
    case Buffered_Bit_Stream:
        bits = s.recorded
    case Random_Bit_Stream:
        bits = s.recorded
    }

    return bits
}

draw_bits_buffered :: proc(s: ^Buffered_Bit_Stream, n_bits: int) -> u64 {
    val: u64
    
    group_id := begin_group(&s.recorded, "fix the label")

    if len(s.buffer) == 0 {
        panic("Tried to draw bits from an empty buffer")
    }
        
    current := pop_front(&s.buffer)
    mask := (u64(1) << u64(n_bits)) - 1
    val = current & mask
    append(&s.recorded.data, val)
    
    end_group(&s.recorded, group_id)

    return val
}

draw_bits_random :: proc(s: ^Random_Bit_Stream, n_bits: int) -> u64 {
    val: u64
    
    group_id := begin_group(&s.recorded, "fix the other label")
    mask := (u64(1) << u64(n_bits)) - 1
    val = rand.uint64() & mask
    append(&s.recorded.data, val)
    end_group(&s.recorded, group_id)

    return val
}
