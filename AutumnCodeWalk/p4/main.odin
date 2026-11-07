package main

import "core:fmt"
import "core:os"
import "core:slice/heap"
import "core:strings"

void :: struct {}

Point :: struct {
	x: int,
	y: int,
}

LEFT :: Point{-1, 0}
RIGHT :: Point{1, 0}
UP :: Point{0, -1}
DOWN :: Point{0, 1}
INVALID :: Point{-1, -1}

DIRECTIONS :: []Point{LEFT, UP, RIGHT, DOWN}

Input :: struct {
	world_size: Point,
	maze:       map[Point]void,
	origin:     Point,
	box:        Point,
	target:     Point,
}

point_add :: proc(a: Point, b: Point) -> Point {
	return Point{a.x + b.x, a.y + b.y}
}

point_neg :: proc(a: Point) -> Point {
	return Point{-a.x, -a.y}
}

read_input :: proc(input: string) -> (content: Input, ok: bool) {
	data, err := os.read_entire_file(input, context.allocator)
	if err != nil do return Input{}, false

	defer delete(data, context.allocator)

	content = Input {
		maze = make(map[Point]void),
	}
	it := string(data)
	y := 0
	for line in strings.split_lines_iterator(&it) {
		for x := 0; x < len(line); x += 1 {
			switch line[x] {
			case 'T':
				content.target = Point{x, y}
			case 'X':
				content.origin = Point{x, y}
			case '*':
				content.box = Point{x, y}
			case '#':
				content.maze[Point{x, y}] = {}
			}
		}

		y += 1
		content.world_size.y = y
		if content.world_size.x == 0 {
			content.world_size.x = len(line)
		}
	}

	return content, true
}

ScoredState :: struct {
	pos:   Point,
	box:   Point,
	score: int,
}

State :: struct {
	pos: Point,
	box: Point,
}

state_cmp :: proc(a: ScoredState, b: ScoredState) -> bool {
	return a.score > b.score
}

solve :: proc(maze: map[Point]void, size: Point, origin: Point, box: Point, target: Point) -> int {
	queue := make([dynamic]ScoredState)
	defer delete(queue)

	append(&queue, ScoredState{origin, box, 0})
	heap.make(queue[:], state_cmp)

	state_cache := make(map[State]int)
	defer delete(state_cache)

	for len(queue) > 0 {
		heap.pop(queue[:], state_cmp)
		current := pop(&queue)

		state := State{current.pos, current.box}
		if state in state_cache {
			if state_cache[state] > current.score {
				panic("Found shorter path later?")
			}
			continue
		} else {
			state_cache[state] = current.score
		}

		if current.box == target {
			return current.score
		}

		for dir in DIRECTIONS {
			if next, ok := push_box(maze, size, current.pos, current.box, dir); ok {
				next.score += current.score
				append(&queue, next)
				heap.push(queue[:], state_cmp)
			}
		}
	}

	return -1
}

is_open :: proc(maze: map[Point]void, size: Point, point: Point, extra: Point) -> bool {
	if point.x < 0 || point.x >= size.x || point.y < 0 || point.y >= size.y {
		return false
	}
	return !(point in maze) && point != extra
}

push_box :: proc(
	maze: map[Point]void,
	size: Point,
	pos: Point,
	box: Point,
	dir: Point,
) -> (
	next: ScoredState,
	ok: bool,
) {
	box_destination := point_add(box, dir)
	if !is_open(maze, size, box_destination, INVALID) {
		return ScoredState{}, false
	}

	pos_push_destination := point_add(box, point_neg(dir))
	if !is_open(maze, size, pos_push_destination, INVALID) {
		return ScoredState{}, false
	}

	distance := pathfind(maze, size, pos, box, pos_push_destination)
	if distance < 0 {
		return ScoredState{}, false
	}

	return ScoredState{box, box_destination, distance + 1}, true
}

pathfind :: proc(maze: map[Point]void, size: Point, pos: Point, box: Point, target: Point) -> int {
	queue_raw := make([dynamic]Point)
	next_queue_raw := make([dynamic]Point)
	defer delete(queue_raw)
	defer delete(next_queue_raw)

	append(&queue_raw, pos)
	queue := &queue_raw
	next_queue := &next_queue_raw

	visited := make(map[Point]void)
	defer delete(visited)

	distance := 0
	for len(queue^) > 0 {
		for len(queue^) > 0 {
			current := pop(queue)

			if current in visited {
				continue
			} else {
				visited[current] = {}
			}

			if current == target {
				return distance
			}

			for dir in DIRECTIONS {
				next := point_add(current, dir)
				if is_open(maze, size, next, box) {
					append(next_queue, next)
				}
			}
		}

		distance += 1
		tmp := queue
		queue = next_queue
		next_queue = tmp
	}

	return -1
}

main :: proc() {
	if data, ok := read_input("input"); ok {
		// fmt.printfln("size: %d x %d", data.world_size.x, data.world_size.y)
		// fmt.printfln("origin: x:%d y:%d", data.origin.x, data.origin.y)
		// fmt.printfln("target: x:%d y:%d", data.target.x, data.target.y)
		// fmt.printfln("box: x:%d y:%d", data.box.x, data.box.y)
		// fmt.printfln("walls: %d", len(data.maze))

		fmt.printfln("%d", solve(data.maze, data.world_size, data.origin, data.box, data.target))
	}
}
