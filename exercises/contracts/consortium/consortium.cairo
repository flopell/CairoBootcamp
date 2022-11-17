%lang starknet
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.starknet.common.syscalls import get_caller_address, get_block_timestamp
from starkware.cairo.common.math import unsigned_div_rem, assert_le_felt, assert_le, assert_nn
from starkware.cairo.common.math_cmp import is_le
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.pow import pow
from starkware.cairo.common.hash_state import hash_init, hash_update
from starkware.cairo.common.bitwise import bitwise_and, bitwise_xor, bitwise_or
from lib.constants import TRUE, FALSE

// Structs
//#########################################################################################

struct Consortium {
    chairperson: felt,
    proposal_count: felt,
}

struct Member {
    votes: felt,
    prop: felt,
    ans: felt,
}

struct Answer {
    text: felt,
    votes: felt,
}

struct Proposal {
    type: felt,  // whether new answers can be added
    win_idx: felt,  // index of preffered option
    ans_idx: felt,
    deadline: felt,
    over: felt,
}

// remove in the final asnwerless
struct Winner {
    highest: felt,
    idx: felt,
}

// Storage
//#########################################################################################

@storage_var
func consortium_idx() -> (idx: felt) {
}

@storage_var
func consortiums(consortium_idx: felt) -> (consortium: Consortium) {
}

@storage_var
func members(consortium_idx: felt, member_addr: felt) -> (memb: Member) {
}

@storage_var
func proposals(consortium_idx: felt, proposal_idx: felt) -> (win_idx: Proposal) {
}

@storage_var
func proposals_idx(consortium_idx: felt) -> (idx: felt) {
}

@storage_var
func proposals_title(consortium_idx: felt, proposal_idx: felt, string_idx: felt) -> (
    substring: felt
) {
}

@storage_var
func proposals_link(consortium_idx: felt, proposal_idx: felt, string_idx: felt) -> (
    substring: felt
) {
}

@storage_var
func proposals_answers(consortium_idx: felt, proposal_idx: felt, answer_idx: felt) -> (
    answers: Answer
) {
}

@storage_var
func voted(consortium_idx: felt, proposal_idx: felt, member_addr: felt) -> (true: felt) {
}

@storage_var
func answered(consortium_idx: felt, proposal_idx: felt, member_addr: felt) -> (true: felt) {
}


//
// Modifiers
//

func assert_only_chairperson{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(consortium_idx: felt){
    let (caller) = get_caller_address();
    let (consortium) = consortiums.read(consortium_idx);
    let chairperson = consortium.chairperson;
    with_attr error_message("Consortium : You must be chairperson to call that function"){
    assert caller = chairperson;
    }
    return();
}

// External functions
//#########################################################################################

@external
func create_consortium{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    let (caller) = get_caller_address();
    let (idx) = consortium_idx.read();
    let new_consortium = Consortium(chairperson=caller,proposal_count=0);
    let new_member = Member(votes=100, prop=TRUE, ans=TRUE);
    consortiums.write(idx,new_consortium);
    members.write(idx, caller, new_member); 
    let new_idx = idx+1;
    consortium_idx.write(new_idx);
    return ();
}

@external
func add_proposal{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    consortium_idx: felt,
    title_len: felt,
    title: felt*,
    link_len: felt,
    link: felt*,
    ans_len: felt,
    ans: felt*,
    type: felt,
    deadline: felt,
) {
    alloc_locals;
    assert_only_chairperson(consortium_idx);
    let (prop_idx) = proposals_idx.read(consortium_idx);
    proposals_idx.write(consortium_idx,prop_idx+1);
    load_selector(title_len,title,0,prop_idx,consortium_idx,0,0);
    load_selector(link_len,link,0,prop_idx,consortium_idx,1,0);
    load_selector(ans_len,ans,0,prop_idx,consortium_idx,2,0);
    let new_proposal = Proposal(type=type, win_idx=0, ans_idx=ans_len ,deadline=deadline, over= FALSE);
    proposals.write(consortium_idx,prop_idx,new_proposal);
    return ();
}

@external
func add_member{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    consortium_idx: felt, member_addr: felt, prop: felt, ans: felt, votes: felt
) {
    assert_only_chairperson(consortium_idx);
    let new_member = Member(votes=votes, prop=prop, ans=ans);
    members.write(consortium_idx,member_addr,new_member);
    return ();
}

@external
func add_answer{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    consortium_idx: felt, proposal_idx: felt, string_len: felt, string: felt*
) {
    alloc_locals;
    let (caller) = get_caller_address();
    let (proposal) = proposals.read(consortium_idx,proposal_idx);
    with_attr error_message("Consortium : No new answers can be added"){
        assert proposal.type = 1;
    }
    let offset = proposal.ans_idx;
    load_selector(string_len,string,0,proposal_idx,consortium_idx,2,offset);
    answered.write(consortium_idx,proposal_idx,caller,TRUE);
    return ();
}

@external
func vote_answer{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    consortium_idx: felt, proposal_idx: felt, answer_idx: felt
) { 
    let (proposal) = proposals.read(consortium_idx,proposal_idx);
    with_attr error_message("Consortium : Proposal is over"){
        assert proposal.over = FALSE;
    }
    let (caller) = get_caller_address();
    let (_voted) = voted.read(consortium_idx,proposal_idx,caller);
    with_attr error_message("Consortium : User has already voted for this proposal"){
        assert _voted = 0;
    }
    let (member) = members.read(consortium_idx,caller);
    let (curr_state) = proposals_answers.read(consortium_idx,proposal_idx,answer_idx);
    let new_state = Answer(curr_state.text,curr_state.votes+member.votes);
    proposals_answers.write(consortium_idx,proposal_idx,answer_idx,new_state);
    voted.write(consortium_idx,proposal_idx,caller,TRUE);
    return ();
}

@external
func tally{syscall_ptr: felt*,pedersen_ptr: HashBuiltin*, range_check_ptr}(
    consortium_idx: felt, proposal_idx: felt
) -> (win_idx: felt) {
    alloc_locals;
    let (caller) = get_caller_address();
    let (timestamp) = get_block_timestamp();
    let (proposal) = proposals.read(consortium_idx,proposal_idx);
    let deadline = proposal.deadline;
    let has_ended = is_le(deadline,timestamp);
    if (has_ended == 0) {
        assert_only_chairperson(consortium_idx);
        tempvar syscall_ptr=syscall_ptr;
        tempvar pedersen_ptr=pedersen_ptr;
        tempvar range_check_ptr=range_check_ptr;
    } else {
        tempvar syscall_ptr=syscall_ptr;
        tempvar pedersen_ptr=pedersen_ptr;
        tempvar range_check_ptr=range_check_ptr;
    }
    let (win_idx) = find_highest(consortium_idx,proposal_idx,0,0,3+1);
    let new_proposal = Proposal(type=0, win_idx=win_idx, ans_idx=proposal.ans_idx ,deadline=proposal.deadline, over=TRUE);
    proposals.write(consortium_idx,proposal_idx,new_proposal);
    return (win_idx,);
}


// Internal functions
//#########################################################################################


func find_highest{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    consortium_idx: felt, proposal_idx: felt, highest: felt, idx: felt, countdown: felt
) -> (idx: felt) {
    alloc_locals;
    if (countdown == 0){
        return(idx,);
    }
    let (ans) = proposals_answers.read(consortium_idx,proposal_idx,countdown);
    let is_bigger = is_le(highest,ans.votes);
    if (is_bigger == 1) {
        let (index) = find_highest(consortium_idx,proposal_idx,ans.votes,countdown,countdown-1);
    } else {
        let (index) = find_highest(consortium_idx,proposal_idx,highest,idx,countdown-1);
    }
    return (index,);    
}

// Loads it based on length, internal calls only
func load_selector{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    string_len: felt,
    string: felt*,
    slot_idx: felt,
    proposal_idx: felt,
    consortium_idx: felt,
    selector: felt,
    offset: felt,
) { 
    alloc_locals;
    let recursion_end = string_len - slot_idx;
    if (recursion_end == 0 ){
        return();
    }

    load_selector(string_len,string,slot_idx+1,proposal_idx,consortium_idx,selector,offset);

    if (selector == 0) {
        proposals_title.write(consortium_idx,proposal_idx,slot_idx,string[slot_idx]);
        tempvar syscall_ptr=syscall_ptr;
        tempvar pedersen_ptr=pedersen_ptr;
        tempvar range_check_ptr=range_check_ptr;
    } else {
    tempvar syscall_ptr=syscall_ptr;
    tempvar pedersen_ptr=pedersen_ptr;
    tempvar range_check_ptr=range_check_ptr;
    }
    if (selector == 1) {
        proposals_link.write(consortium_idx,proposal_idx,slot_idx,string[slot_idx]);
        tempvar syscall_ptr=syscall_ptr;
        tempvar pedersen_ptr=pedersen_ptr;
        tempvar range_check_ptr=range_check_ptr;
    } else {
    tempvar syscall_ptr=syscall_ptr;
    tempvar pedersen_ptr=pedersen_ptr;
    tempvar range_check_ptr=range_check_ptr;
    }
    if (selector == 2) {
        let new_ans = Answer(string[slot_idx],0);
        proposals_answers.write(consortium_idx,proposal_idx,slot_idx+offset,new_ans);
        tempvar syscall_ptr=syscall_ptr;
        tempvar pedersen_ptr=pedersen_ptr;
        tempvar range_check_ptr=range_check_ptr;
    } else {
    tempvar syscall_ptr=syscall_ptr;
    tempvar pedersen_ptr=pedersen_ptr;
    tempvar range_check_ptr=range_check_ptr;
    }
    return ();
}
