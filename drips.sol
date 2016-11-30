pragma solidity ^0.4.2;

contract Bollot {
    
    struct Voter{
        bool res;
        bool op;
        bool exists;
    }
    
    enum proStages {
        ProposalOperational,
        ProposalFailure,
        ProposalSuccess,
        ProposalClose
    }
    
    uint256 public cId;
    uint256 public pId;
    address public raiser;
    string public content;
    address public receiver;
    uint public money;
    uint256 public expireTime;
    
    mapping (address => Voter) voteState;
    uint passedNums;
    uint votedNums;
    uint voters;
    uint state;

    event ProposalResultEvent(uint256, uint256, bool);
    event NewProposalEvent(address, uint256, uint256, string, address, uint256, uint256);
    event NewVoteEvent(address, uint256, uint256, bool);
    event VoteStateEvent(address, uint256, bool, bool);

    function Bollot(address[] _availAddrs, uint256 _cId, uint256 _pId, address _raiser, string _content, address _receiver, uint _money, uint256 _expireTime){
        cId = _cId;
        pId = _pId;
        raiser = _raiser;
        content = _content;
        receiver = _receiver;
        money = _money;
        expireTime = _expireTime;
        voters = _availAddrs.length;
        for (uint i = 0; i < voters; i++) {
            voteState[_availAddrs[i]].op = false;
            voteState[_availAddrs[i]].exists = true;
            VoteStateEvent(_availAddrs[i], pId, voteState[_availAddrs[i]].exists, voteState[_availAddrs[i]].op);
        }
        state = uint(proStages.ProposalOperational);
        NewProposalEvent(_raiser, cId, pId, _content, _receiver, _money, _expireTime);
    }
    
    function isOver() returns (bool){
        return (now > expireTime || votedNums == voters);
    }
    
    function vote(address _voter, bool _res) {
        if (isOver()) {
            checkProposalStage();
            return;
        }
        var sdr = _voter;
        var boll = voteState[sdr];
        VoteStateEvent(_voter, pId, boll.exists, boll.op);
        if (!boll.exists || boll.op) throw;
        if (_res) passedNums += 1;
        votedNums += 1;
        voteState[sdr].res = _res;
        voteState[sdr].op = true;
        NewVoteEvent(_voter, cId, pId, _res);
        checkProposalStage();
    }
    
    function getProposalReceiver() returns (address) {
        return receiver;
    }

    function getProposalRaiser() returns (address) {
        return raiser;
    }

    function isProposalExecuable(address _raiser) returns (bool) {
        return state == uint(proStages.ProposalSuccess) && _raiser == raiser;
    }
    
    function closeProposal() public {
        state = uint(proStages.ProposalClose);
    }
    
    function checkProposalStage() {
        if (isOver()) {
            if (passedNums > voters - passedNums) {
                state = uint(proStages.ProposalSuccess);
                ProposalResultEvent(cId, pId, true);
            } else {
                state = uint(proStages.ProposalFailure);
                ProposalResultEvent(cId, pId, false);
            }
        }
    }
    
    function getMoney() returns (uint) {
        return money;
    }
    
    function waiver(address voterAddr){
        quit(voterAddr);
    }
    
    function quit(address voterAddr) private{
        var voter = voteState[voterAddr];
        if (!voter.exists) throw;
        voters -= 1;
        if(voter.op) votedNums -= 1;
        if(voter.res) passedNums -= 1;
    }
    
}


contract CrowdFund {
    
    enum cfStages {
        CrowdFundOperational,
        CrowdFundFailure,
        CrowdFundSuccess
    }
    
    uint256 public cId;
    address public organizer;
    string public name;
    uint public quota;
    uint256 public unitPrice;
    uint256 public expireTime;

    uint256 quotaRaised;
    mapping (uint => address) voters;   // map used to transfer to voter array
    mapping (address => uint) donators; // map used to record donator and donator nums
    uint public state;
    uint donatorNum;
    mapping (uint => Bollot) proposals;
    uint proposalIndex;
    // address[] voterList;
    
    event ProposalUpdateEvent(uint256, address, uint);
    event RefundUpdateEvent(uint256, address, uint, bool);
    event CrowdStateUpdateEvent(uint256, uint);
    event NewCrowdFundEvent(uint256, address, string, uint, uint256, uint256);
    event NewDenoteCrowdFundEvent(uint256, address, uint256);
    
    function CrowdFund (uint256 _cId, address _organizer, string _name, uint _quota, uint256 _unitPrice, uint256 _expireTime) {
        cId = _cId;
        organizer = _organizer;
        name = _name;
        quota = _quota;
        unitPrice = _unitPrice;
        expireTime = _expireTime;
        state = uint(cfStages.CrowdFundOperational);
        NewCrowdFundEvent(_cId, _organizer, _name, _quota, _unitPrice, _expireTime);
    }
    
    function donate(address _donator, uint _money) payable public {
        if (now > expireTime) {
            checkCrowdFundStage();
            return;
        }
        uint _quota = _money / unitPrice;
        if (_quota != 0) {
            if (donators[_donator] == 0) {
                voters[donatorNum] = _donator;
                NewDenoteCrowdFundEvent(cId, voters[donatorNum], donators[_donator]);
                donatorNum++;
            }
            donators[_donator] += _quota;
            quotaRaised += _quota;
            NewDenoteCrowdFundEvent(cId, _donator, donators[_donator]);
            checkCrowdFundStage();
        }
    }
    
    function checkCrowdFundStage() public{
        // if (now > expireTime) {
            if (quotaRaised < quota) {
                state = uint(cfStages.CrowdFundFailure);
            } else {
                state = uint(cfStages.CrowdFundSuccess);
            }
            CrowdStateUpdateEvent(cId, state);
        // }
    }

    function getDonatorMoney(address _donator) public returns (uint) {
        return donators[_donator] * unitPrice;
    }

    function updateAfterRefund(address _donator) public {
        RefundUpdateEvent(cId, _donator, donators[_donator] * unitPrice, true);
        quotaRaised -= donators[_donator];
        donators[_donator] = 0;
        for (uint i = 0; i < proposalIndex; i++) {
            proposals[proposalIndex].waiver(_donator);
        }
    }
    
    function isRefundable() public returns (bool){
        return state != uint(cfStages.CrowdFundOperational);
    }
    
    function proposal(address _raiser, string _content, address _receiver, uint256 _money, uint256 _expireTime) public {
        address[] memory voterList = new address[](donatorNum);
        for (uint i = 0; i < donatorNum; i++) {
            voterList[i] = voters[i];
            ProposalUpdateEvent(cId, voters[i], i);
            ProposalUpdateEvent(cId, voterList[i], i);
        }
        proposalIndex++;
        Bollot bollot = new Bollot(voterList, cId, proposalIndex, _raiser, _content, _receiver, _money, _expireTime);
        proposals[proposalIndex] = bollot;
    }
    
    function vote(address _voter, uint256 _pId, bool _decide) public {
        proposals[_pId].vote(_voter, _decide);
    }

    function getProposal(uint256 _pId) public returns (Bollot) {
        return proposals[_pId];
    }
    
    function updateAfterExecuteProposal(uint256 _pId) public {
         // reduce money of each count
         uint _money = proposals[_pId].getMoney();
         uint _reduceRate = unitPrice * quotaRaised / _money;
         for (uint i = 0; i < donatorNum; i++) {
             address _donator = voters[i];
             donators[_donator] -= donators[_donator] / _reduceRate;
             ProposalUpdateEvent(cId, _donator, donators[_donator]);
         }
    }
}


contract CrowdFundFactory {
    
    // map of CrowdFund Index to CrowdFund
    mapping (uint256 => CrowdFund) crowdFunds;
    // index of CrowdFund
    uint256 cfIndex;
    
    event RefundEvent(uint256, address, uint);
    
    // create a new CrowdFund
    function newCrowdFund(string _name, uint _quota, uint256 _unitPrice, uint256 _expireTime) public {
        cfIndex += 1;
        address _organizer = msg.sender;
        CrowdFund _cf  = new CrowdFund(cfIndex, _organizer, _name, _quota, _unitPrice, _expireTime);
        crowdFunds[cfIndex] = _cf;
    }
    
    // donate to a CrowdFund
    function donate(uint256 _cId) payable public {
        address _donator = msg.sender;
        uint256 _money = msg.value;
        crowdFunds[_cId].donate(_donator, _money);
    }
    
    // refund from a CrowdFund
    function refund(uint256 _cId) public {
        address _donator = msg.sender;
        if (!crowdFunds[_cId].isRefundable()) throw;
        uint _money = crowdFunds[_cId].getDonatorMoney(_donator);
        RefundEvent(_cId, _donator, _money);
        if (_donator.send(_money)) {
            crowdFunds[_cId].updateAfterRefund(_donator);
        } else {
            throw;
        }
    }
    
    // raise a new proposal in a specific CrowdFund
    // A propsoal include raiser, content, receiver, money need to spend and expire time 
    function newProposal(uint256 _cId, string _content, address _receiver, uint _money, uint256 _expireTime) {
        address _raiser = msg.sender;
        crowdFunds[_cId].proposal(_raiser, _content, _receiver, _money, _expireTime);
    }

    // vote for a proposal in a specific CrowdFund
    function vote(uint256 _cId, uint256 _pId, bool _decide) {
        address _voter = msg.sender;
        crowdFunds[_cId].vote(_voter, _pId, _decide);
    }
    
    function executeProposal(uint256 _cId, uint256 _pId) {
         address _raiser = msg.sender;
         Bollot proposal = crowdFunds[_cId].getProposal(_pId);
         if (proposal.isProposalExecuable(_raiser)) {
            if (_raiser.send(proposal.getMoney())) {
                proposal.closeProposal();
                crowdFunds[_cId].updateAfterExecuteProposal(_pId);
            } else {
                throw;
            }
         }
    }
}