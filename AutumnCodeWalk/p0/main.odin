package main

import "core:fmt"
import "core:os"
import "core:strings"

Input :: struct {
	haystack: string,
	needles:  [dynamic]string,
}

read_input :: proc(input: string) -> (content: Input, ok: bool) {
	data, err := os.read_entire_file(input, context.allocator)
	if err != nil do return Input{}, false

	defer delete(data, context.allocator)

	content = Input{"", make([dynamic]string, 0, 1000)}
	it := string(data)
	i := 0
	for line in strings.split_lines_iterator(&it) {
		if i == 0 {
			content.haystack = strings.clone(line)
		} else {
			append(&content.needles, strings.clone(line))
		}
		i += 1
	}

	return content, true
}

// starts_with by ignoring spaces from slice
try_match :: proc(slice: string, needle: string) -> bool {
	i := 0
	for n in 0 ..< len(needle) {
		for i < len(slice) && slice[i] == ' ' {
			i += 1
		}
		if i >= len(slice) {
			return false
		}
		if needle[n] != slice[i] {
			return false
		}
		i += 1
	}
	return true
}

walk :: proc(data: Input) -> int {
	word_index := 0

	matches := make([dynamic]int, len(data.needles))
	for &value in matches {
		value = -1
	}
	defer delete(matches)

	for i in 0 ..< len(data.haystack) {
		if data.haystack[i] == ' ' {
			word_index += 1
			continue
		}

		for needle, n in data.needles {
			if matches[n] == -1 {
				if try_match(data.haystack[i:], needle) {
					matches[n] = word_index
				}
			}
		}
	}

	sum := 0
	for m in matches {
		sum += m
	}
	return sum
}

main :: proc() {
	if data, ok := read_input("input"); ok {
		result := walk(data)
		fmt.printfln("%d", result)
	}
}
