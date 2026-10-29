package main

import "core:fmt"
import "core:os"
import "core:strings"
import "core:thread"

Node :: struct {
	name:        string,
	connections: [dynamic]string,
}

read_input :: proc(input: string) -> (network: map[string][dynamic]string, ok: bool) {
	data, err := os.read_entire_file(input, context.allocator)
	if err != nil do return nil, false

	defer delete(data, context.allocator)

	network = make(map[string][dynamic]string)
	it := string(data)
	for line in strings.split_lines_iterator(&it) {
		nodes := strings.split(line, " -- ")
		for n in nodes {
			if !(n in network) {
				network[strings.clone(n)] = make([dynamic]string)
			}
		}

		node, _ := &network[nodes[0]]
		append(node, strings.clone(nodes[1]))
		node, _ = &network[nodes[1]]
		append(node, strings.clone(nodes[0]))
	}

	return network, true
}

SolverData :: struct {
	network: map[string][dynamic]string,
	origin:  string,
	result:  int,
}

threaded_solve_one :: proc(task: thread.Task) {
	data := cast(^SolverData)task.data
	network := data^.network
	visited := make(map[string]bool)
	data^.result = solve_one_rec(network, data^.origin, &visited)
	delete(visited)
}

solve_one_rec :: proc(
	network: map[string][dynamic]string,
	current: string,
	visited: ^map[string]bool,
) -> int {
	best := len(visited) - 1
	if current in visited {
		return best
	}

	visited[current] = true
	for node in network[current] {
		next := solve_one_rec(network, node, visited)
		best = max(best, next)
	}
	delete_key(visited, current)

	return best
}

solve :: proc(network: map[string][dynamic]string) -> int {
	solver_data := make([dynamic]SolverData)
	for k, v in network {
		if len(v) == 1 {
			append(&solver_data, SolverData{network, strings.clone(k), 0})
		}
	}

	THREADS :: 8
	pool: thread.Pool
	thread.pool_init(&pool, context.allocator, THREADS)
	thread.pool_start(&pool)
	defer thread.pool_destroy(&pool)

	for i in 0 ..< len(solver_data) {
		thread.pool_add_task(&pool, context.allocator, threaded_solve_one, &solver_data[i], i)
	}

	thread.pool_finish(&pool)

	best := 0
	for i in 0 ..< len(solver_data) {
		task, _ := thread.pool_pop_done(&pool)
		result := solver_data[task.user_index].result
		best = max(best, result)
	}

	return best
}

main :: proc() {
	if network, ok := read_input("input"); ok {
		fmt.printfln("%d", solve(network))
	}
}
