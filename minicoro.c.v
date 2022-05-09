/*
* minicoro: Wrapper for minicoro.h
 *
 * Copyright (c) 2022 Steven 'lazalong' Gay
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
 * OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
 * IN THE SOFTWARE.
*/
module minicoro

$if debug {
	#define MCO_DEBUG
}

#define MINICORO_IMPL
#flag -I @VMODROOT/include
#include "minicoro.h"

[callconv: 'fastcall']
pub type FuncCoro = fn (co &Coro)

[callconv: 'fastcall']
pub type FreeCB = fn (ptr voidptr, allocator_data voidptr)

[callconv: 'fastcall']
pub type MallocCB = fn (size usize, allocator_data voidptr) voidptr // [void* (*malloc_cb)(size_t size, void* allocator_data);]

// CONSTANTS //
pub const (
	minicoro_v_version = '0.0.3'
	minicoro_c_version = '0.1.3'
)

pub const (
	default_stack_size = C.MCO_DEFAULT_STACK_SIZE
	min_stack_size     = C.MCO_MIN_STACK_SIZE
)

// State represents all coroutine states.
pub enum State {
	dead = 0 // The coroutine has finished normally or was uninitialized before finishing.
	normal // The coroutine is active but not running (that is, it has resumed another coroutine).
	running // The coroutine is active and running.
	suspended // The coroutine is suspended (in a call to yield, or it has not started running yet).
}

// Result holds coroutine result codes.
pub enum Result {
	success = 0
	generic_error
	invalid_pointer
	invlid_coroutine
	not_suspended
	not_running
	make_context_error
	switch_context_error
	not_enough_space
	out_of_memory
	invalid_arguments
	invalid_operation
	stack_overflow
}

[typedef]
struct C.mco_coro {
pub mut:
	context         voidptr
	state           State
	func            FuncCoro // [void (*func)(mco_coro* co);]
	prev_co         &Coro = 0
	user_data       voidptr
	allocator_data  voidptr
	free_cb         FreeCB  // [void (*free_cb)(void* ptr, void* allocator_data);]
	stack_base      voidptr // Stack base address, can be used to scan memory in a garbage collector.
	stack_size      usize
	storage         &byte = 0
	bytes_stored    usize
	storage_size    usize
	asan_prev_stack voidptr // Used by address sanitizer.
	tsan_prev_fiber voidptr // Used by thread sanitizer.
	tsan_fiber      voidptr // Used by thread sanitizer.
	magic_number    usize   // Used to check stack overflow.
}

// Coro is the coroutine structure.
pub type Coro = C.mco_coro

[typedef]
struct C.mco_desc {
pub mut:
	func      FuncCoro // Entry point function for the coroutine. [void (*func)(mco_coro* co);]
	user_data voidptr  // Coroutine user data, can be get with `mco_get_user_data`.
	// Custom allocation interface.
	malloc_cb      MallocCB // Custom allocation function.   [void* (*malloc_cb)(size_t size, void* allocator_data);]
	free_cb        FreeCB   // Custom deallocation function. [void  (*free_cb)(void* ptr, void* allocator_data);]
	allocator_data voidptr  // User data pointer passed to `malloc`/`free` allocation functions.
	storage_size   usize    // Coroutine storage size, to be used with the storage APIs.
	// These must be initialized only through `mco_init_desc`.
	coro_size  usize // Coroutine structure size.
	stack_size usize // Coroutine stack size.
}

// Desc is a structure used to initialize a coroutine.
pub type Desc = C.mco_desc

// FUNCTIONS //
// Coroutine functions.
fn C.mco_desc_init(co FuncCoro, stack_size usize) Desc

// desc_init initializes a description of a coroutine.
// When `stack_size` is 0 then `default_stack_size` is used.
pub fn desc_init(co FuncCoro, stack_size usize) Desc {
	return C.mco_desc_init(co, stack_size)
}

fn C.mco_init(co &Coro, desc &Desc) Result

// init initializes the coroutine.
pub fn init(co &Coro, desc &Desc) Result {
	return C.mco_init(co, desc)
}

fn C.mco_uninit(co &Coro) Result

// uninit uninitializes the coroutine `co`,
// may fail if it's not dead or suspended.
pub fn uninit(co &Coro) Result {
	return C.mco_uninit(co)
}

fn C.mco_create(out_co &&Coro, desc &Desc) Result

// create allocates and initializes a new coroutine.
pub fn create(out_co &&Coro, desc &Desc) Result {
	return C.mco_create(out_co, desc)
}

fn C.mco_destroy(co &Coro) Result

// destroy uninitializes and deallocates the coroutine,
// the function may fail if it's not dead or suspended.
pub fn destroy(co &Coro) Result {
	return C.mco_destroy(co)
}

fn C.mco_resume(co &Coro) Result

// resume starts or continues the execution of the coroutine.
pub fn resume(co &Coro) Result {
	return C.mco_resume(co)
}

fn C.mco_yield(co &Coro) Result

// yield suspends (yields) the execution of a coroutine.
pub fn yield(co &Coro) Result {
	return C.mco_yield(co)
}

fn C.mco_status(co &Coro) State

// status returns the status of the coroutine.
pub fn status(co &Coro) State {
	return C.mco_status(co)
}

fn C.mco_get_user_data(co &Coro) voidptr

// get_user_data gets coroutine user data supplied on coroutine creation.
pub fn get_user_data(co &Coro) voidptr {
	return C.mco_get_user_data(co)
}

// Storage interface functions, used to pass values between yield and resume.
fn C.mco_push(co &Coro, src voidptr, len usize) Result

// push pushes bytes to the coroutine storage.
// Use to send values between yield and resume.
pub fn push(co &Coro, src voidptr, len usize) Result {
	return C.mco_push(co, src, len)
}

fn C.mco_pop(co &Coro, dest voidptr, len usize) Result

// pop pops bytes from the coroutine storage.
// Use to get values between yield and resume.
pub fn pop(co &Coro, dest voidptr, len usize) Result {
	return C.mco_pop(co, dest, len)
}

fn C.mco_peek(co &Coro, dest voidptr, len usize) Result

// peek works like `pop` but it does not consume the storage.
pub fn peek(co &Coro, dest voidptr, len usize) Result {
	return C.mco_peek(co, dest, len)
}

fn C.mco_get_bytes_stored(co &Coro) usize

// get_bytes_stored gets the available bytes that can be retrieved with a `pop`.
pub fn get_bytes_stored(co &Coro) usize {
	return C.mco_get_bytes_stored(co)
}

fn C.mco_get_storage_size(co &Coro) usize

// get_storage_size gets the total storage size.
pub fn get_storage_size(co &Coro) usize {
	return C.mco_get_storage_size(co)
}

// Misc functions.
fn C.mco_running() &Coro

// running returns the running coroutine for the current thread.
pub fn running() &Coro {
	return C.mco_running()
}

fn C.mco_result_description(res Result) &char

// result_description gets the description of a result.
pub fn result_description(res Result) &char {
	return C.mco_result_description(res)
}
