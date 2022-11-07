%lang starknet
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.bitwise import bitwise_and, bitwise_xor
from starkware.cairo.common.uint256 import (
    Uint256,
    uint256_le,
    uint256_unsigned_div_rem,
    uint256_sub,
    uint256_signed_nn_le,
    assert_uint256_eq,
    assert_uint256_le
)
from starkware.starknet.common.syscalls import get_caller_address
from starkware.cairo.common.math import (
    assert_not_zero,
    assert_not_equal,
    assert_nn,
    assert_le,
    assert_lt,
    assert_in_range
)
from exercises.contracts.erc20.ERC20_base import (
    ERC20_name,
    ERC20_symbol,
    ERC20_totalSupply,
    ERC20_decimals,
    ERC20_balanceOf,
    ERC20_allowance,
    ERC20_mint,
    ERC20_initializer,
    ERC20_transfer,
    ERC20_burn,
)

@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    name: felt, symbol: felt, initial_supply: Uint256, recipient: felt
) {
    ERC20_initializer(name, symbol, initial_supply, recipient);
    admin.write(recipient);
    return ();
}

// Storage
//#########################################################################################

@storage_var
func admin() -> (name: felt) {
}

@storage_var
func WL_addresses(address: felt) -> (res: felt) {
}


// View functions
//#########################################################################################

@view
func name{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (name: felt) {
    let (name) = ERC20_name();
    return (name,);
}

@view
func get_admin{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    admin_address: felt
) {
    let (admin_address) = admin.read();
    return (admin_address,);
}
@view
func symbol{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (symbol: felt) {
    let (symbol) = ERC20_symbol();
    return (symbol,);
}

@view
func totalSupply{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    totalSupply: Uint256
) {
    let (totalSupply: Uint256) = ERC20_totalSupply();
    return (totalSupply,);
}

@view
func decimals{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    decimals: felt
) {
    let (decimals) = ERC20_decimals();
    return (decimals,);
}

@view
func balanceOf{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(account: felt) -> (
    balance: Uint256
) {
    let (balance: Uint256) = ERC20_balanceOf(account);
    return (balance,);
}

@view
func allowance{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    owner: felt, spender: felt
) -> (remaining: Uint256) {
    let (remaining: Uint256) = ERC20_allowance(owner, spender);
    return (remaining,);
}

// Externals
//###############################################################################################


//transfer function can only be used to transfer even amount.
@external
func transfer{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr,bitwise_ptr: BitwiseBuiltin*}(
    recipient: felt, amount: Uint256
) -> (success: felt) {
    let (_,rem) = uint256_unsigned_div_rem(amount,Uint256(2,0));
    let isEven = uint256_le(rem,Uint256(0,0));
    with_attr error_message("NOT EVEN AMOUNT"){
    assert_uint256_eq(rem,Uint256(0,0));
    }
    ERC20_transfer(recipient, amount);
    return (1,);
}

//faucet function mints tokens to caller address, it reverts if amount is greater than 10 000.
@external
func faucet{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(amount: Uint256) -> (
    success: felt
) {
    with_attr error_message("NOT EVEN AMOUNT"){
    assert_uint256_le(amount,Uint256(10000,0));
    }
    let (caller) = get_caller_address();
    ERC20_mint(caller, amount);
    return (1,);
}


//burn function sends 10% of the burnt amount to the owner and burn the remainer amount.
@external
func burn{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(amount: Uint256) -> (
    success: felt
) {
    alloc_locals;
    let (local caller) = get_caller_address();
    let (local owner) = get_admin();
    let (_10percentsOfAmount, _) = uint256_unsigned_div_rem(amount,Uint256(10,0));
    let (_amountToBurn) = uint256_sub(amount,_10percentsOfAmount);
    ERC20_transfer(owner, _10percentsOfAmount);
    ERC20_burn(caller,_amountToBurn);
    return (1,);
}

//request_whitelist function whitelists the caller address.
@external
func request_whitelist{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    level_granted: felt
) {
    let (caller) = get_caller_address();
    WL_addresses.write(caller, 1);
    return (1,);
}

//check_whitelist function return 1 in the account is whitelisted, return 0 if it's not.
@external
func check_whitelist{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    account: felt
) -> (allowed_v: felt) {
    let (caller) = get_caller_address();
    let (isWL) = WL_addresses.read(caller);
    return (isWL,);
}

//exclusive_faucet function mints any amount of tokens to the caller address, it requires the caller address to be whitelisted.
@external
func exclusive_faucet{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    amount: Uint256
) -> (success: felt) {
    let (caller) = get_caller_address();
    let (isWL) = check_whitelist(caller);
    with_attr error_message("Caller is not whitelisted"){
    assert isWL = 1;
    }
    ERC20_mint(caller, amount);
    return (success=1);
}

// @external
// func exclusive_faucet{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
//     amount: Uint256
// ) -> (success: felt) {
//     alloc_locals;
//     let (local caller) = get_caller_address();
//     let (local is_whitelisted) = check_whitelist(caller); 
//     if(is_whitelisted == 1) {
//          ERC20_mint(caller, amount);
//          tempvar syscall_ptr=syscall_ptr;
//          tempvar pedersen_ptr=pedersen_ptr;
//          tempvar range_check_ptr=range_check_ptr;
//     } else {
//          let (local result) = faucet(amount);
//          assert result = 1;
//          tempvar syscall_ptr=syscall_ptr;
//          tempvar pedersen_ptr=pedersen_ptr;
//          tempvar range_check_ptr=range_check_ptr;
//     }
//     return (success=1);
// }