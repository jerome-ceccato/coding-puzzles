package main

import "core:encoding/base64"
import "core:fmt"
import "core:os"
import "core:strconv"

read_input :: proc(input: string) -> (binary: []byte, ok: bool) {
	data, err := os.read_entire_file(input, context.allocator)
	if err != nil do return nil, false

	defer delete(data, context.allocator)

	decoded, err2 := base64.decode(string(data))
	if err2 != nil do return nil, false

	return decoded, true
}

decode :: proc(data: []byte) -> (result: int, ok: bool) {
	next := data
	current_line: []byte

	next = try_consume(next, []byte{0xc5, 0xc7, 0x57, '\n'}) or_return
	// fmt.println("magic number")

	current_line, next = try_get_line(next) or_return
	references := strconv.parse_int(string(current_line), 10) or_return
	// fmt.printfln("referenced objects: %d", references)

	reference_table := make([dynamic]int, references)
	for n in 0 ..< references {
		current_line, next = try_get_line(next) or_return
		reference_table[n] = strconv.parse_int(string(current_line), 10) or_return
		// fmt.printfln("offset %d: %d", n, reference_table[n])
	}

	checksum := 0
	for n in 0 ..< references {
		result, _ := get_fingerprint(data[reference_table[n]:]) or_return
		checksum += n * result
	}

	return checksum, true
}

get_fingerprint :: proc(data: []byte) -> (result: int, next: []byte, ok: bool) {
	next = data
	next = skip_whitespaces(next)

	switch next[0] {
	case '"':
		return get_fingerprint_string(next)
	case '0' ..= '9', '+', '-':
		return get_fingerprint_int(next)
	case 't', 'f':
		return get_fingerprint_bool(next)
	case 'n':
		return get_fingerprint_nil(next)
	case '{':
		return get_fingerprint_map(next)
	case '[':
		return get_fingerprint_array(next)
	case:
		fmt.printfln("Cannot parse type: |%s|", string(next[:10]))
		return 0, next, false
	}
}

get_fingerprint_string :: proc(data: []byte) -> (result: int, next: []byte, ok: bool) {
	result = 0
	next = data[1:]

	i := 0
	n := 0
	for ; i < len(next) && next[i] != '"'; i += 1 {
		if next[i] == '\\' {
			i += 1
		}
		n += 1
	}

	// fmt.printfln("found string %s", next[:i])
	return n, next[i + 1:], true
}

get_fingerprint_int :: proc(data: []byte) -> (result: int, next: []byte, ok: bool) {
	result = 0
	next = data
	line: []byte

	line, _ = try_get_line(next) or_return
	parsed := 0
	n, _ := strconv.parse_int(string(line), 10, &parsed)
	// fmt.printfln("found int %d", n)
	return abs(n), next[parsed:], true
}

get_fingerprint_bool :: proc(data: []byte) -> (result: int, next: []byte, ok: bool) {
	result = 0
	next = data

	if next[0] == 't' {
		next = try_consume(next, []u8{'t', 'r', 'u', 'e'}) or_return
		// fmt.printfln("found true")
		return 1, next, true
	} else {
		next = try_consume(next, []u8{'f', 'a', 'l', 's', 'e'}) or_return
		// fmt.printfln("found false")
		return 0, next, true
	}
}

get_fingerprint_nil :: proc(data: []byte) -> (result: int, next: []byte, ok: bool) {
	result = 0
	next = data
	next = try_consume(next, []u8{'n', 'i', 'l'}) or_return
	// fmt.printfln("found nil")
	return 31, next, true
}

get_fingerprint_map :: proc(data: []byte) -> (result: int, next: []byte, ok: bool) {
	result = 0
	next = data[1:]

	acc := 3
	for {
		next = skip_whitespaces(next)
		if next[0] == '}' {
			return acc, next[1:], true
		}

		key, value := 0, 0
		key, next = get_fingerprint_string(next) or_return

		next = skip_whitespaces(next)
		next = try_consume(next, []byte{'=', '>'}) or_return

		value, next = get_fingerprint(next) or_return
		acc += key * value
	}
	return 0, next, true
}

get_fingerprint_array :: proc(data: []byte) -> (result: int, next: []byte, ok: bool) {
	result = 0
	next = data[1:]

	acc := 1
	tmp: int
	for {
		next = skip_whitespaces(next)
		if next[0] == ']' {
			next = next[1:]
			return acc, next, true
		}

		tmp, next = get_fingerprint(next) or_return
		acc += tmp
		next = skip_whitespaces(next)
		if next[0] == ';' {
			next = next[1:]
		} else if next[0] != ']' {
			fmt.printfln("Invalid array, expected ; or ], found %s", next)
			return 0, next, false
		}
	}

	return 0, next, true
}

skip_whitespaces :: proc(data: []byte) -> []byte {
	for i in 0 ..< len(data) {
		if data[i] != ' ' && data[i] != '\n' {
			return data[i:]
		}
	}
	return nil
}

try_consume :: proc(data: []byte, expected: []byte) -> (next: []byte, ok: bool) {
	for i in 0 ..< len(expected) {
		if i >= len(data) || data[i] != expected[i] {
			return nil, false
		}
	}
	return data[len(expected):], true
}

try_get_line :: proc(data: []byte) -> (line: []byte, next: []byte, ok: bool) {
	for i := 0; i < len(data); i += 1 {
		if data[i] == '\n' {
			return data[:i], data[i + 1:], true
		}
	}
	return nil, nil, false
}

main :: proc() {
	if data, ok := read_input("input"); ok {
		// fmt.printfln("input size: %d", len(data))
		// fmt.printfln("---\n%s\n---", string(data))
		if result, ok := decode(data); ok {
			fmt.printfln("%d", result)
		}
	}
}
