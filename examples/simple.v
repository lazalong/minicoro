module main

import lazalong.minicoro

[callconv: 'fastcall']
pub fn coro_entry(co &minicoro.Coro) {
	println('  Coroutine 1 - magic nb: $co.magic_number')
	res := minicoro.yield(co)
	str_res := unsafe { cstring_to_vstring(minicoro.result_description(res)) }
	println('  Coroutine 2 - magic nb: $co.magic_number "$str_res"')
}

[console]
fn main() {
	println('Simple Minicoro Example')

	// First initialize a `desc` object through `mco_desc_init`.
	fct := voidptr(&coro_entry)
	mut desc := minicoro.desc_init(fct, 0)

	// Configure `desc` fields when needed (e.g. customize user_data or allocation functions).
	desc.user_data = voidptr(0)
	mut co := &minicoro.Coro{}

	// Call `mco_create` with the output coroutine pointer and `desc` pointer.
	mut res := minicoro.create(&co, &desc)
	assert res == .success
	// println(res)

	// The coroutine should be now in suspended state.
	assert minicoro.status(co) == .suspended

	// Call `mco_resume` to start for the first time, switching to its context.
	res = minicoro.resume(co) // Should print "coroutine 1".
	assert res == .success

	// We get back from coroutine context in suspended state
	// because the coro_entry method yields after the first print
	assert minicoro.status(co) == .suspended

	// Call `mco_resume` to resume for a second time.
	res = minicoro.resume(co) // Should print "coroutine 2".
	assert res == .success

	// The coroutine finished and should be now dead.
	assert minicoro.status(co) == .dead

	// Call `mco_destroy` to destroy the coroutine.
	res = minicoro.destroy(co)
	assert res == .success
}
