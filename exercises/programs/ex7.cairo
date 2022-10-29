%lang starknet
from starkware.cairo.common.bitwise import bitwise_and, bitwise_xor
from starkware.cairo.common.cairo_builtins import BitwiseBuiltin
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import unsigned_div_rem

// Using binary operations return:
// - 1 when pattern of bits is 01010101 from LSB up to MSB 1, but accounts for trailing zeros
// - 0 otherwise

// 000000101010101 PASS
// 010101010101011 FAIL
 
// i.e : we need to check parity is always different after shifting right

func pattern{bitwise_ptr: BitwiseBuiltin*, range_check_ptr}(
    n: felt, idx: felt, exp: felt, broken_chain: felt
) -> (true: felt) {

    // shift right n >> 1
    let (q,r) = unsigned_div_rem(n,2);
    
    //if it's last iteration : test passed
    if (q == 0) {
        return(true=1);
    }
    let (isParityDifferent) = bitwise_xor(r,exp);


    %{print(f"n : {ids.n}")%}
    %{print(f"rem : {ids.r}, exp : {ids.exp}")%}
    %{print(f"quo : {ids.q}, passOrFail:{ids.isParityDifferent}, idx : {ids.idx}")%}
    %{print(" ")%}


    //if parity is not different from last : test failed
    if (isParityDifferent == 0 and idx != 0) {
        %{print(f"pattern broken, last two n have same parity")%}
        return(true=0);
    }

    let (res) = pattern(n=q,idx=idx+1,exp=r,broken_chain=broken_chain);
    return (true=res);
}
