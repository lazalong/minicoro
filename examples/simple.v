module main

import lazalong.minicoro

[callconv: 'fastcall']
pub fn coro_entry(co &C.mco_coro) {
	println('  Coroutine 1 - magic nb: $co.magic_number')
	C.mco_yield(co)
	println('  Coroutine 2 - magic nb: $co.magic_number')
}

[console]
fn main() {
	println('Simple Minicoro Test')

	// First initialize a `desc` object through `mco_desc_init`.
	fct := voidptr(&coro_entry)
	mut desc := C.mco_desc_init(fct, 0)

	// Configure `desc` fields when needed (e.g. customize user_data or allocation functions).
	desc.user_data = voidptr(0)
	mut co := &minicoro.Coro{}

	// Call `mco_create` with the output coroutine pointer and `desc` pointer.
	mut res := C.mco_create(&co, &desc)
	assert res == minicoro.Result.success
	// println(res)

	// The coroutine should be now in suspended state.
	assert C.mco_status(co) == minicoro.State.suspended

	// Call `mco_resume` to start for the first time, switching to its context.
	res = C.mco_resume(co) // Should print "coroutine 1".
	assert res == minicoro.Result.success

	// We get back from coroutine context in suspended state
	// because the coro_entry method yields after the first print
	assert C.mco_status(co) == minicoro.State.suspended

	// Call `mco_resume` to resume for a second time.
	res = C.mco_resume(co) // Should print "coroutine 2".
	assert res == minicoro.Result.success

	// The coroutine finished and should be now dead.
	assert C.mco_status(co) == minicoro.State.dead

	// Call `mco_destroy` to destroy the coroutine.
	res = C.mco_destroy(co)
	assert res == minicoro.Result.success
}
