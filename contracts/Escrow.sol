//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";


enum Status {
  NONE,
  APPROVED,
  REFUNDED,
  RECLAIM_EXPIRED // escrow is expired and reclaimed by depositor
}

struct Deposit {
  uint id;
  uint amount;
  uint expire;
  address depositor;
  address receiver;
  address approver;
  Status status;
}

contract Escrow is Ownable {
  uint public expiration;

  uint private nonce;

  mapping(address => bool) public isApprover;

  mapping(uint => Deposit) public deposits; // deposit id => deposit

  mapping(address => uint[]) public escrowsPerDepositor; // depositor => array of his escrows

  event Deposited(uint amount, address indexed receiver, address indexed approver);

  event Approved(uint amount, address indexed receiver);

  event Refunded(uint amount, address indexed depositor, address indexed receiver);

  event Reclaimed(uint amount, address indexed depositor);

  constructor(uint expiration_) {
    expiration = expiration_;
    nonce = 1;
  }

  modifier onlyApprover {
    require(isApprover[msg.sender], "You are not an approver");
    _;
  }

  receive () external payable { }

  /**
   * @dev add approver
   * @param approver approver's address
   */
  function addApprover(address approver) external onlyOwner {
    isApprover[approver] = true;
  }

  /**
   * @dev depositFor
   * @param amount uint
   * @param receiver address
   * @param approver address 
   */
  function depositFor(
    uint amount,
    address receiver,
    address approver
  ) external
    payable
  {
    require(amount == msg.value, "Amount mismatch");
    uint id = nonce++;

    Deposit storage dep = deposits[id];
    dep.id = id;
    dep.amount = amount;
    dep.depositor = msg.sender;
    dep.receiver = receiver;
    dep.approver = approver;
    dep.status = Status.NONE;
    dep.expire = block.timestamp + expiration;

    escrowsPerDepositor[msg.sender].push(id);

    emit Deposited(amount, receiver, approver);
  }

  /**
   * @dev approver approves an escrow given by id
   * @param id escrow id
   */
  function approve(uint id) external onlyApprover {
    Deposit storage dep = deposits[id];

    require(dep.id == id, "Invalid id");
    require(dep.status == Status.NONE, "Deposit status already touched");
    require(dep.approver == msg.sender, "You are not an appropriate approver");

    (bool sent,) = payable(dep.receiver).call{value: dep.amount}("");
    require(sent, "Failed to send ETH to receiver");

    dep.status = Status.APPROVED;

    emit Approved(dep.amount, dep.receiver);
  }

  /**
   * @dev approver refunds an escrow given by id
   * @param id escrow id
   */
  function refund(uint id) external onlyApprover {
    Deposit storage dep = deposits[id];

    require(dep.id == id, "Invalid id");
    require(dep.status == Status.NONE, "Deposit status already touched");
    require(dep.approver == msg.sender, "You are not an appropriate approver");


    (bool sent,) = payable(dep.depositor).call{value: dep.amount}("");
    require(sent, "Failed to send ETH to depositor");

    dep.status = Status.REFUNDED;

    emit Refunded(dep.amount, dep.depositor, dep.receiver);
  }

  /**
   * @dev depositor reclaims an expired escrows
   */
  function reclaimExpired() external {
    uint amount = 0;

    for (uint i = 0; i < escrowsPerDepositor[msg.sender].length; i++) {
      uint id = escrowsPerDepositor[msg.sender][i];
      Deposit storage dep = deposits[id];

      if (dep.status == Status.NONE && dep.expire <= block.timestamp) {
        dep.status = Status.RECLAIM_EXPIRED;
        amount += dep.amount;
      }
    }

    (bool sent,) = payable(msg.sender).call{value: amount}("");
    require(sent, "Failed to send ETH to reclaimer");
    emit Reclaimed(amount, msg.sender);
  }
}
