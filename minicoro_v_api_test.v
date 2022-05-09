module minicoro

[callconv: 'fastcall']
pub fn coro_entry(co &Coro) {
	yield(co)
}

[console]
fn test_simple() {
	// First initialize a `desc` object through `mco_desc_init`.
	fct := voidptr(&coro_entry)
	mut desc := desc_init(fct, 0)

	// Configure `desc` fields when needed (e.g. customize user_data or allocation functions).
	desc.user_data = voidptr(0)
	mut co := &Coro{}

	// Call `mco_create` with the output coroutine pointer and `desc` pointer.
	mut res := create(&co, &desc)
	assert res == .success
	// println(res)

	// The coroutine should be now in suspended state.
	assert status(co) == .suspended

	// Call `mco_resume` to start for the first time, switching to its context.
	res = resume(co) // Should print "coroutine 1".
	assert res == .success

	// We get back from coroutine context in suspended state
	// because the coro_entry method yields after the first print
	assert status(co) == .suspended

	// Call `mco_resume` to resume for a second time.
	res = resume(co) // Should print "coroutine 2".
	assert res == .success

	// The coroutine finished and should be now dead.
	assert status(co) == .dead

	// Call `mco_destroy` to destroy the coroutine.
	res = destroy(co)
	assert res == .success
}
