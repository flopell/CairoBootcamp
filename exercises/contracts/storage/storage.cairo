// Task:
// Develop logic of set balance and get balance methods
%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import assert_nn

// Define a storage variable.
@storage_var
func balance() -> (res: felt) {
}

// Returns the current balance.
@view
func get_balance{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr,
}() -> (res: felt) {
    let res = balance.read();
    return (res);
}

// Sets the balance to amount
@external
func set_balance{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr,
}(amount: felt) {
    // //Use this if balance must be positive
    // with_attr error_message("Amount must be positive. Got: {amount}."){
    //     assert_nn(amount);
    // }   
    balance.write(amount);
    return();
}
