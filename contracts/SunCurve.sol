// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { SunToken } from "./SunToken.sol";

contract SunCurve is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20Metadata;
    using SafeERC20 for SunToken;

    uint256 public constant BPS = 10_000;
    uint256 public constant FEE_TO_CURVE_BPS = 150;
    uint256 public constant FEE_TO_PROTOCOL_BPS = 50;

    error InvalidAddress();
    error InvalidAmount();
    error InvalidUSDTDecimals();
    error MaxMintExceeded();
    error BurnAmountExceedsSupply();
    error NotMoonCurve();
    error NotMoonAMM();
    error SameBlockMintBurn();

    SunToken public immutable sunToken;
    IERC20Metadata public immutable usdt;
    address public immutable protocolBudget;
    uint256 public immutable maxMintUsdt;
    uint256 public immutable usdtTo18Scale;

    uint256 public curveReserve;
    uint256 public lastMintBlock;
    address public moonCurve;
    address public moonAMM;

    event SunMinted(
        address indexed payer,
        address indexed receiver,
        uint256 usdtIn,
        uint256 sunOut,
        uint256 feeToCurve,
        uint256 feeToProtocol
    );
    event SunBurned(
        address indexed payer,
        address indexed receiver,
        uint256 sunIn,
        uint256 usdtOut,
        uint256 feeToCurve,
        uint256 feeToProtocol
    );
    event BurnAndRetain(address indexed caller, uint256 sunAmount);
    event UsdtInjected(address indexed caller, uint256 usdtAmount);
    event MoonCurveSet(address indexed moonCurve);
    event MoonAMMSet(address indexed moonAMM);

    constructor(
        SunToken sunToken_,
        IERC20Metadata usdt_,
        address protocolBudget_,
        uint256 maxMintUsdt_,
        address initialOwner
    ) Ownable(initialOwner) {
        if (
            address(sunToken_) == address(0) || address(usdt_) == address(0)
                || protocolBudget_ == address(0)
        ) {
            revert InvalidAddress();
        }
        if (maxMintUsdt_ == 0) revert InvalidAmount();

        uint8 usdtDecimals = usdt_.decimals();
        if (usdtDecimals > 18) revert InvalidUSDTDecimals();

        sunToken = sunToken_;
        usdt = usdt_;
        protocolBudget = protocolBudget_;
        maxMintUsdt = maxMintUsdt_;
        usdtTo18Scale = 10 ** uint256(18 - usdtDecimals);
    }

    function setMoonCurve(address newMoonCurve) external onlyOwner {
        if (newMoonCurve == address(0)) revert InvalidAddress();

        moonCurve = newMoonCurve;

        emit MoonCurveSet(newMoonCurve);
    }

    function setMoonAMM(address newMoonAMM) external onlyOwner {
        if (newMoonAMM == address(0)) revert InvalidAddress();

        moonAMM = newMoonAMM;

        emit MoonAMMSet(newMoonAMM);
    }

    function mint(uint256 usdtIn) external nonReentrant returns (uint256 sunOut) {
        return _mintSun(msg.sender, msg.sender, usdtIn);
    }

    function mintFor(address receiver, uint256 usdtIn)
        external
        nonReentrant
        returns (uint256 sunOut)
    {
        return _mintSun(msg.sender, receiver, usdtIn);
    }

    function burn(uint256 sunIn) external nonReentrant returns (uint256 usdtOut) {
        return _burnSun(msg.sender, msg.sender, sunIn);
    }

    function burnTo(address receiver, uint256 sunIn)
        external
        nonReentrant
        returns (uint256 usdtOut)
    {
        return _burnSun(msg.sender, receiver, sunIn);
    }

    function burnAndRetain(uint256 sunAmount) external nonReentrant {
        if (msg.sender != moonCurve) revert NotMoonCurve();
        if (sunAmount == 0) revert InvalidAmount();
        if (sunAmount > sunToken.totalSupply()) revert BurnAmountExceedsSupply();

        sunToken.burn(address(this), sunAmount);

        emit BurnAndRetain(msg.sender, sunAmount);
    }

    function injectUSDT(uint256 usdtAmount) external nonReentrant {
        if (msg.sender != moonAMM) revert NotMoonAMM();
        if (usdtAmount == 0) revert InvalidAmount();

        curveReserve += usdtAmount;
        usdt.safeTransferFrom(msg.sender, address(this), usdtAmount);

        emit UsdtInjected(msg.sender, usdtAmount);
    }

    function getSunPrice() public view returns (uint256) {
        uint256 totalSupply = sunToken.totalSupply();
        if (totalSupply == 0) return 0;

        return Math.mulDiv(curveReserve, 1e18, totalSupply);
    }

    function _mintSun(address payer, address receiver, uint256 usdtIn)
        private
        returns (uint256 sunOut)
    {
        if (receiver == address(0)) revert InvalidAddress();
        if (usdtIn == 0) revert InvalidAmount();
        if (usdtIn > maxMintUsdt) revert MaxMintExceeded();

        uint256 reserveBefore = curveReserve;
        uint256 supplyBefore = sunToken.totalSupply();
        uint256 feeToCurve = Math.mulDiv(usdtIn, FEE_TO_CURVE_BPS, BPS);
        uint256 feeToProtocol = Math.mulDiv(usdtIn, FEE_TO_PROTOCOL_BPS, BPS);
        uint256 usdtNet = usdtIn - feeToCurve - feeToProtocol;
        uint256 reserveAdd = usdtIn - feeToProtocol;

        if (supplyBefore == 0) {
            sunOut = usdtNet * usdtTo18Scale;
        } else {
            sunOut = Math.mulDiv(supplyBefore, usdtNet, reserveBefore);
        }

        curveReserve = reserveBefore + reserveAdd;
        lastMintBlock = block.number;

        usdt.safeTransferFrom(payer, address(this), usdtIn);
        usdt.safeTransfer(protocolBudget, feeToProtocol);
        sunToken.mint(receiver, sunOut);

        emit SunMinted(payer, receiver, usdtIn, sunOut, feeToCurve, feeToProtocol);
    }

    function _burnSun(address payer, address receiver, uint256 sunIn)
        private
        returns (uint256 usdtOut)
    {
        if (receiver == address(0)) revert InvalidAddress();
        if (sunIn == 0) revert InvalidAmount();
        if (lastMintBlock == block.number) revert SameBlockMintBurn();

        uint256 totalSupply = sunToken.totalSupply();
        if (sunIn > totalSupply) revert BurnAmountExceedsSupply();

        uint256 usdtGross = Math.mulDiv(curveReserve, sunIn, totalSupply);
        uint256 feeToCurve = Math.mulDiv(usdtGross, FEE_TO_CURVE_BPS, BPS);
        uint256 feeToProtocol = Math.mulDiv(usdtGross, FEE_TO_PROTOCOL_BPS, BPS);
        usdtOut = usdtGross - feeToCurve - feeToProtocol;

        curveReserve -= usdtOut + feeToProtocol;

        sunToken.safeTransferFrom(payer, address(this), sunIn);
        sunToken.burn(address(this), sunIn);
        usdt.safeTransfer(protocolBudget, feeToProtocol);
        usdt.safeTransfer(receiver, usdtOut);

        emit SunBurned(payer, receiver, sunIn, usdtOut, feeToCurve, feeToProtocol);
    }
}
