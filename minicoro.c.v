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
type FuncCoro = fn (co &Coro)

[callconv: 'fastcall']
type FreeCB = fn (ptr voidptr, allocator_data voidptr)

[callconv: 'fastcall']
type MallocCB = fn (size usize, allocator_data voidptr) voidptr // [void* (*malloc_cb)(size_t size, void* allocator_data);]

// CONSTANTS //
pub const (
	minicoro_v_version = '0.0.2'
	minicoro_c_version = '0.1.3'
)

// STRUCTS //
pub enum State { // Coroutine states
	dead = 0 // The coroutine has finished normally or was uninitialized before finishing.
	normal // The coroutine is active but not running (that is, it has resumed another coroutine).
	running // The coroutine is active and running.
	suspended // The coroutine is suspended (in a call to yield, or it has not started running yet).
}

pub enum Result { // Coroutine result codes.
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
pub struct C.mco_coro {
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

// Coroutine structure.
pub type Coro = C.mco_coro

[typedef]
pub struct C.mco_desc {
pub mut: 
	func           FuncCoro // Entry point function for the coroutine. [void (*func)(mco_coro* co);]
	user_data      voidptr  // Coroutine user data, can be get with `mco_get_user_data`.
	// Custom allocation interface.
	malloc_cb      MallocCB // Custom allocation function.   [void* (*malloc_cb)(size_t size, void* allocator_data);]
	free_cb        FreeCB   // Custom deallocation function. [void  (*free_cb)(void* ptr, void* allocator_data);]
	allocator_data voidptr  // User data pointer passed to `malloc`/`free` allocation functions.
	storage_size   usize    // Coroutine storage size, to be used with the storage APIs.
	// These must be initialized only through `mco_init_desc`.
	coro_size      usize    // Coroutine structure size.
	stack_size     usize    // Coroutine stack size.
}

// Structure used to initialize a coroutine.
pub type Desc = C.mco_desc

// FUNCTIONS //
// Coroutine functions.
fn C.mco_desc_init(co FuncCoro, stack_size usize) Desc // Initialize description of a coroutine. When stack size is 0 then MCO_DEFAULT_STACK_SIZE is used.
fn C.mco_init(co &Coro, desc &Desc) Result // Initialize the coroutine.
fn C.mco_uninit(co &Coro) Result // Uninitialize the coroutine, may fail if it's not dead or suspended.
fn C.mco_create(out_co &&Coro, desc &Desc) Result // Allocates and initializes a new coroutine.
fn C.mco_destroy(co &Coro) Result // Uninitialize and deallocate the coroutine, may fail if it's not dead or suspended.
fn C.mco_resume(co &Coro) Result // Starts or continues the execution of the coroutine.
fn C.mco_yield(co &Coro) Result // Suspends the execution of a coroutine.
fn C.mco_status(co &Coro) State // Returns the status of the coroutine.
fn C.mco_get_user_data(co &Coro) voidptr // Get coroutine user data supplied on coroutine creation.

// Storage interface functions, used to pass values between yield and resume.
fn C.mco_push(co &Coro, src voidptr, len usize) Result // Push bytes to the coroutine storage. Use to send values between yield and resume.
fn C.mco_pop(co &Coro, dest voidptr, len usize) Result // Pop bytes from the coroutine storage. Use to get values between yield and resume.
fn C.mco_peak(co &Coro, dest voidptr, len usize) Result // Like `mco_pop` but it does not consumes the storage.
fn C.mco_get_bytes_stored(co &Coro) usize // Get the available bytes that can be retrieved with a `mco_pop`.
fn C.mco_get_storage_size(co &Coro) usize // Get the total storage size.

// Misc functions.
fn C.mco_coro() voidptr // Returns the running coroutine for the current thread.
fn C.mco_result_description(res Result) byteptr // Get the description of a result.
