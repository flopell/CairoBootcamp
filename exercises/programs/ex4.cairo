// Return summation of every number below and up to including n
func calculate_sum(n: felt) -> (sum: felt) {
    if (n == 0){
        return (0,);
    }

    let (res) = calculate_sum(n-1);

    return (res+n,);
}
