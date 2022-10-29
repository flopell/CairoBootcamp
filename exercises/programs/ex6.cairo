from starkware.cairo.common.bitwise import bitwise_and, bitwise_xor
from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, HashBuiltin

// Implement a function that sums even numbers from the provided array
func sum_even{bitwise_ptr: BitwiseBuiltin*}(arr_len: felt, arr: felt*, run: felt, idx: felt) -> (
    sum: felt
) {
    if (idx == arr_len){
        return(0,);
    }
    let (res) = sum_even(arr_len,arr,0,idx+1);

    //get parity of this number : = 0 if even, = 1 if odd
    let (isOdd) = bitwise_and(arr[idx],1);

    //if even : add this number to sum
    if (isOdd == 0){
        return (res+arr[idx],);
    }
    //else : ignore this number
    return (res,);
}
