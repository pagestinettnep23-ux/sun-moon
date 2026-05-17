// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract MoonToken is ERC20, Ownable {
    error InvalidAddress();
    error MinterAlreadyLocked();
    error NotMinter();

    address public minter;
    bool public minterLocked;

    event MinterLocked(address indexed minter);

    constructor(string memory name_, string memory symbol_, address initialOwner)
        ERC20(name_, symbol_)
        Ownable(initialOwner)
    { }

    function setMinter(address newMinter) external onlyOwner {
        if (newMinter == address(0)) revert InvalidAddress();
        if (minterLocked) revert MinterAlreadyLocked();

        minter = newMinter;
        minterLocked = true;

        emit MinterLocked(newMinter);
    }

    function mint(address to, uint256 amount) external onlyMinter {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external onlyMinter {
        _burn(from, amount);
    }

    modifier onlyMinter() {
        if (msg.sender != minter) revert NotMinter();
        _;
    }
}
