// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { MoonCurveMath } from "./libraries/MoonCurveMath.sol";
import { MoonToken } from "./MoonToken.sol";
import { SunCurve } from "./SunCurve.sol";
import { SunToken } from "./SunToken.sol";

contract MoonCurve is Ownable, ReentrancyGuard {
    using SafeERC20 for SunToken;

    error InvalidAddress();
    error InvalidAmount();
    error InvalidCurveParameter();
    error MintNotLaunched();
    error MaxMintExceeded();
    error SameBlockMintBurn();

    MoonToken public immutable moonToken;
    SunToken public immutable sunToken;
    SunCurve public immutable sunCurve;
    address public immutable protocolBudget;
    uint256 public immutable k;
    uint256 public immutable s;
    uint256 public immutable launchTime;
    uint256 public immutable maxMintUsdtEquiv;

    uint256 public sunReserve;
    mapping(address => uint256) public lastMintBlock;

    event MoonMinted(
        address indexed payer,
        address indexed receiver,
        uint256 sunIn,
        uint256 moonOut,
        uint256 feeToSunCurve,
        uint256 feeToProtocol
    );
    event MoonBurned(
        address indexed payer,
        address indexed receiver,
        uint256 moonIn,
        uint256 sunOut,
        uint256 feeToSunCurve,
        uint256 feeToProtocol
    );

    constructor(
        MoonToken moonToken_,
        SunToken sunToken_,
        SunCurve sunCurve_,
        address protocolBudget_,
        uint256 k_,
        uint256 s_,
        uint256 launchTime_,
        uint256 maxMintUsdtEquiv_,
        address initialOwner
    ) Ownable(initialOwner) {
        if (
            address(moonToken_) == address(0) || address(sunToken_) == address(0)
                || address(sunCurve_) == address(0) || protocolBudget_ == address(0)
                || initialOwner == address(0)
        ) {
            revert InvalidAddress();
        }
        if (k_ == 0 || s_ == 0) revert InvalidCurveParameter();
        if (maxMintUsdtEquiv_ == 0) revert InvalidAmount();

        moonToken = moonToken_;
        sunToken = sunToken_;
        sunCurve = sunCurve_;
        protocolBudget = protocolBudget_;
        k = k_;
        s = s_;
        launchTime = launchTime_;
        maxMintUsdtEquiv = maxMintUsdtEquiv_;
    }

    function mint(uint256 sunIn) external nonReentrant returns (uint256 moonOut) {
        return _mintMoon(msg.sender, msg.sender, sunIn);
    }

    function mintFor(address receiver, uint256 sunIn)
        external
        nonReentrant
        returns (uint256 moonOut)
    {
        return _mintMoon(msg.sender, receiver, sunIn);
    }

    function burn(uint256 moonIn) external nonReentrant returns (uint256 sunOut) {
        return _burnMoon(msg.sender, msg.sender, moonIn);
    }

    function burnTo(address receiver, uint256 moonIn)
        external
        nonReentrant
        returns (uint256 sunOut)
    {
        return _burnMoon(msg.sender, receiver, moonIn);
    }

    function currentFairSupply() external view returns (uint256) {
        return MoonCurveMath.totalMinted(k, s, sunReserve);
    }

    function getMintPriceInSUN() public view returns (uint256) {
        return MoonCurveMath.mintPriceInSun(k, s, sunReserve);
    }

    function getMintPriceInUSDT() external view returns (uint256) {
        return MoonCurveMath.priceInUSDT(getMintPriceInSUN(), sunCurve.getSunPrice());
    }

    function quoteMint(uint256 sunIn) external view returns (MoonCurveMath.MintQuote memory) {
        return MoonCurveMath.mintQuote(k, s, sunReserve, sunIn);
    }

    function quoteBurn(uint256 moonIn) external view returns (MoonCurveMath.BurnQuote memory) {
        return MoonCurveMath.burnQuote(k, s, sunReserve, moonIn);
    }

    function timeUntilLaunch() external view returns (uint256) {
        return block.timestamp >= launchTime ? 0 : launchTime - block.timestamp;
    }

    function _mintMoon(address payer, address receiver, uint256 sunIn)
        private
        returns (uint256 moonOut)
    {
        if (receiver == address(0)) revert InvalidAddress();
        if (block.timestamp < launchTime) revert MintNotLaunched();

        uint256 usdtEquiv = MoonCurveMath.usdtEquivalent(sunIn, sunCurve.getSunPrice());
        if (usdtEquiv > maxMintUsdtEquiv) revert MaxMintExceeded();

        MoonCurveMath.MintQuote memory quote = MoonCurveMath.mintQuote(k, s, sunReserve, sunIn);
        moonOut = quote.moonOut;
        sunReserve += quote.sunNet;
        lastMintBlock[payer] = block.number;
        lastMintBlock[receiver] = block.number;

        sunToken.safeTransferFrom(payer, address(this), sunIn);
        sunToken.safeTransfer(address(sunCurve), quote.feeToSunCurve);
        sunCurve.burnAndRetain(quote.feeToSunCurve);
        sunToken.safeTransfer(protocolBudget, quote.feeToProtocol);
        moonToken.mint(receiver, moonOut);

        emit MoonMinted(payer, receiver, sunIn, moonOut, quote.feeToSunCurve, quote.feeToProtocol);
    }

    function _burnMoon(address payer, address receiver, uint256 moonIn)
        private
        returns (uint256 sunOut)
    {
        if (receiver == address(0)) revert InvalidAddress();
        if (lastMintBlock[payer] == block.number) revert SameBlockMintBurn();

        MoonCurveMath.BurnQuote memory quote = MoonCurveMath.burnQuote(k, s, sunReserve, moonIn);
        sunOut = quote.sunOut;
        sunReserve = quote.nextSunReserve;

        moonToken.burn(payer, moonIn);
        sunToken.safeTransfer(address(sunCurve), quote.feeToSunCurve);
        sunCurve.burnAndRetain(quote.feeToSunCurve);
        sunToken.safeTransfer(protocolBudget, quote.feeToProtocol);
        sunToken.safeTransfer(receiver, sunOut);

        emit MoonBurned(payer, receiver, moonIn, sunOut, quote.feeToSunCurve, quote.feeToProtocol);
    }
}
