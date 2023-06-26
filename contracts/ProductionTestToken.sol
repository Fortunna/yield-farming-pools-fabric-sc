// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import "./mock/MockToken.sol";

contract ProductionTestToken is MockToken {
    constructor(
        string memory name,
        string memory symbol,
        uint256 initialSupply
    ) MockToken(name, symbol, initialSupply) {}

    function setBlockTransfers(bool _block) public override onlyOwner {
        super.setBlockTransfers(_block);
    }

    function setTransfersAllowed(
        address sender,
        address recipient,
        bool _allowed
    ) public override onlyOwner {
        super.setTransfersAllowed(sender, recipient, _allowed);
    }

    function setBlockTransfersFrom(bool _block) public override onlyOwner {
        super.setBlockTransfersFrom(_block);
    }

    function setBalanceOf(
        address who,
        uint256 amount
    ) public override onlyOwner {
        super.setBalanceOf(who, amount);
    }

    function transfer(
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        return super.transfer(recipient, amount);
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        return super.transferFrom(sender, recipient, amount);
    }

    function mint(address account, uint256 amount) public override onlyOwner {
        super.mint(account, amount);
    }

    function burn(address account, uint256 amount) public override onlyOwner {
        super.burn(account, amount);
    }
}
