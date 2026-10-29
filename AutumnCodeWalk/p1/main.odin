package main

import "core:fmt"
import "core:os"
import "core:sort"
import "core:strings"

read_input :: proc(input: string) -> (content: string, ok: bool) {
	data, err := os.read_entire_file(input, context.allocator)
	if err != nil do return "", false
	return string(data), true
}

step1 :: proc(line: string) -> [dynamic]string {
	result := make([dynamic]string)
	for i := 0; i < len(line); i += 1 {
		c := line[i]
		n := 1
		for (i + 1) < len(line) && line[i + 1] == c {
			n += 1
			i += 1
		}
		append(&result, fmt.aprintf("%c%d", c, n))
	}
	return result
}

KeySize :: struct {
	key:  string,
	size: int,
}

keysize_compare :: proc(a: KeySize, b: KeySize) -> int {
	return -sort.compare_ints(a.size, b.size)
}

step2 :: proc(compressed: [dynamic]string) -> string {
	groups := make(map[string]int)
	defer delete(groups)

	// Count unique groups
	for s in compressed {
		value, ok := &groups[s]
		if ok {
			value^ += 1
		} else {
			groups[s] = 1
		}
	}

	keys_to_delete := make([dynamic]string)
	defer delete(keys_to_delete)
	key_size_savings := make([dynamic]KeySize)
	defer delete(key_size_savings)

	// Determine groups to keep and purge
	for k, v in groups {
		raw_size := len(k) * v
		compressed_size := len(k) + v

		if compressed_size >= raw_size {
			append(&keys_to_delete, k)
		} else {
			append(&key_size_savings, KeySize{k, raw_size - compressed_size})
		}
	}
	for k in keys_to_delete {
		delete_key(&groups, k)
	}

	// Keep only the top 26 biggest savings since we have just 26 keys
	if len(key_size_savings) > 26 {
		sort.quick_sort_proc(key_size_savings[:], keysize_compare)
		for k in key_size_savings[26:] {
			delete_key(&groups, k.key)
		}
	}

	// Map remaining groups to letters and write the header
	mapping := make(map[string]u8)
	n: u8 = 0
	result := strings.builder_make()
	for k, v in &groups {
		strings.write_string(&result, k)
		mapping[k] = 'a' + n
		n += 1
	}

	strings.write_string(&result, ";;")
	for g in compressed {
		if g in mapping {
			strings.write_byte(&result, mapping[g])
		} else {
			strings.write_string(&result, g)
		}
	}

	return strings.to_string(result)
}

main :: proc() {
	if contents, ok := read_input("input"); ok {
		sum := 0
		i := 1
		for line in strings.split_lines_iterator(&contents) {
			compressed := step1(line)
			first := strings.join(compressed[:], "")
			second := step2(compressed)
			sum += i * min(len(first), len(second))
			i += 1

			// fmt.printfln("%s -> %s -> %s", line, first, second)
		}
		fmt.printfln("%d", sum)
	}
}
