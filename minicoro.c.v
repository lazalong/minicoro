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
type FuncCoro = fn (co C.mco_coro)

[callconv: 'fastcall']
type FreeCB = fn (ptr voidptr, allocator_data voidptr)

[callconv: 'fastcall']
type MallocCoro = fn (size usize, allocator_data voidptr) voidptr // [void* (*malloc_cb)(size_t size, void* allocator_data);]

// CONSTANTS //
pub const (
	minicoro_v_version = '0.0.1'
	minicoro_c_version = '0.1.3'
)

// STRUCTS //
pub enum Mco_State { // Coroutine states
	mco_dead = 0 // The coroutine has finished normally or was uninitialized before finishing.
	mco_normal // The coroutine is active but not running (that is, it has resumed another coroutine).
	mco_running // The coroutine is active and running.
	mco_suspended // The coroutine is suspended (in a call to yield, or it has not started running yet).
}

pub enum Mco_Result { // Coroutine result codes.
	mco_success = 0
	mco_generic_error
	mco_invalid_pointer
	mco_invlid_coroutine
	mco_not_suspended
	mco_not_running
	mco_make_context_error
	mco_switch_context_error
	mco_not_enough_space
	mco_out_of_memory
	mco_invalid_arguments
	mco_invalid_operation
	mco_stack_overflow
}

[typedef]
pub struct C.mco_coro {
pub mut: // Coroutine structure.
	context         voidptr
	state           Mco_State
	func            FuncCoro // [void (*func)(mco_coro* co);]
	prev_co         &C.mco_coro = 0
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

pub type Mco_Coro = C.mco_coro

[typedef]
pub struct C.mco_desc {
pub mut: // Structure used to initialize a coroutine.
	func      FuncCoro // Entry point function for the coroutine. [void (*func)(mco_coro* co);]
	user_data voidptr  // Coroutine user data, can be get with `mco_get_user_data`.
	// Custom allocation interface.
	malloc_cb      MallocCoro // Custom allocation function.   [void* (*malloc_cb)(size_t size, void* allocator_data);]
	free_cb        FreeCB     // Custom deallocation function. [void  (*free_cb)(void* ptr, void* allocator_data);]
	allocator_data voidptr    // User data pointer passed to `malloc`/`free` allocation functions.
	storage_size   usize      // Coroutine storage size, to be used with the storage APIs.
	// These must be initialized only through `mco_init_desc`.
	coro_size  usize // Coroutine structure size.
	stack_size usize // Coroutine stack size.
}

pub type Mco_Desc = C.mco_desc

// FUNCTIONS //
// Coroutine functions.
fn C.mco_desc_init(co Func_Coro, stack_size usize) Mco_Desc // Initialize description of a coroutine. When stack size is 0 then MCO_DEFAULT_STACK_SIZE is used.
fn C.mco_init(co &Mco_Coro, desc &Mco_Desc) Mco_Result // Initialize the coroutine.
fn C.mco_uninit(co &Mco_Coro) Mco_Result // Uninitialize the coroutine, may fail if it's not dead or suspended.
fn C.mco_create(out_co &&Mco_Coro, desc &Mco_Desc) Mco_Result // Allocates and initializes a new coroutine.
fn C.mco_destroy(co &Mco_Coro) Mco_Result // Uninitialize and deallocate the coroutine, may fail if it's not dead or suspended.
fn C.mco_resume(co &Mco_Coro) Mco_Result // Starts or continues the execution of the coroutine.
fn C.mco_yield(co &Mco_Coro) Mco_Result // Suspends the execution of a coroutine.
fn C.mco_status(co &Mco_Coro) Mco_State // Returns the status of the coroutine.
fn C.mco_get_user_data(co &Mco_Coro) voidptr // Get coroutine user data supplied on coroutine creation.

// Storage interface functions, used to pass values between yield and resume.
fn C.mco_push(co &Mco_Coro, src voidptr, len usize) Mco_Result // Push bytes to the coroutine storage. Use to send values between yield and resume.
fn C.mco_pop(co &Mco_Coro, dest voidptr, len usize) Mco_Result // Pop bytes from the coroutine storage. Use to get values between yield and resume.
fn C.mco_peak(co &Mco_Coro, dest voidptr, len usize) Mco_Result // Like `mco_pop` but it does not consumes the storage.
fn C.mco_get_bytes_stored(co &Mco_Coro) usize // Get the available bytes that can be retrieved with a `mco_pop`.
fn C.mco_get_storage_size(co &Mco_Coro) usize // Get the total storage size.

// Misc functions.
fn C.mco_coro() voidptr // Returns the running coroutine for the current thread.
fn C.mco_result_description(res Mco_Result) byteptr // Get the description of a result.
