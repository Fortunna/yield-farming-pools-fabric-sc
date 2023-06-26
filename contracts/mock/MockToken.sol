// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <=0.8.20;

import "@openzeppelin/contracts-new/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts-new/access/Ownable.sol";

contract MockToken is ERC20, Ownable {
    bool public blockTransfers;
    bool public blockTransfersFrom;

    mapping(address => mapping(address => bool)) public transfersAllowed;

    constructor(
        string memory name,
        string memory symbol,
        uint256 initialSupply
    ) ERC20(name, symbol) {
        _mint(msg.sender, initialSupply);
    }

    function setBlockTransfers(bool _block) public virtual {
        blockTransfers = _block;
    }

    function setTransfersAllowed(
        address sender,
        address recipient,
        bool _allowed
    ) public virtual {
        transfersAllowed[sender][recipient] = _allowed;
    }

    function setBlockTransfersFrom(bool _block) public virtual {
        blockTransfersFrom = _block;
    }

    function setBalanceOf(address who, uint256 amount) public virtual {
        uint256 balance = balanceOf(who);
        if (balance > amount) {
            _burn(who, balance - amount);
        } else if (balance < amount) {
            _mint(who, amount - balance);
        }
    }

    function transfer(
        address recipient,
        uint256 amount
    ) public virtual override returns (bool) {
        if (blockTransfers) {
            if (transfersAllowed[msg.sender][recipient]) {
                super._transfer(msg.sender, recipient, amount);
                return true;
            } else {
                return false;
            }
        } else {
            super._transfer(msg.sender, recipient, amount);
            return true;
        }
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual override returns (bool) {
        if (blockTransfersFrom) {
            if (transfersAllowed[sender][recipient]) {
                return super.transferFrom(sender, recipient, amount);
            } else {
                return false;
            }
        } else {
            return super.transferFrom(sender, recipient, amount);
        }
    }

    function mint(address account, uint256 amount) public virtual {
        _mint(account, amount);
    }

    function burn(address account, uint256 amount) public virtual {
        _burn(account, amount);
    }
}
