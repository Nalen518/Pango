// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// THROWAWAY spike code (S5). Not the Phase 1 PangoVault: it only exists to check the weight math and
// to measure the gas of a buy that runs every SRD check in order, including the target check.

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IB20Asset} from "base-std/interfaces/IB20Asset.sol";

library WeightMath {
    /// USD value, 18 decimals, of `uiAmount` shares (in the token's own decimals) at `price8`.
    /// Feed = USDC per UI share, 8 decimals (SRD FR-V12). If S3 shows the feed is per raw token, this is
    /// the one line to change (use the raw balance instead of balanceOfUI).
    function stockValue18(uint256 uiAmount, uint8 tokenDecimals, uint256 price8) internal pure returns (uint256) {
        return uiAmount * price8 * 1e10 / (10 ** tokenDecimals);
    }

    function usdcValue18(uint256 usdc6) internal pure returns (uint256) {
        return usdc6 * 1e12;
    }

    function weightBps(uint256 part, uint256 total) internal pure returns (uint256) {
        return total == 0 ? 0 : part * 10_000 / total;
    }
}

contract MockUSDC is ERC20 {
    constructor() ERC20("Test USDC", "tUSDC") {}

    function decimals() public pure override returns (uint8) {
        return 6;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

/// Chainlink-style feed, 8 decimals, owner-set answer and updatedAt.
contract MockFeed {
    int256 public answer;
    uint256 public updatedAt;

    function set(int256 a, uint256 t) external {
        answer = a;
        updatedAt = t;
    }

    function decimals() external pure returns (uint8) {
        return 8;
    }

    function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80) {
        return (1, answer, updatedAt, updatedAt, 1);
    }
}

/// Fixed-price pool: sells stock at feed price × (1 + premium).
contract MockSwap {
    IERC20 public immutable usdc;
    mapping(address => uint256) public price8;
    uint256 public premiumBps;

    constructor(IERC20 u) {
        usdc = u;
    }

    function setPrice(address token, uint256 p) external {
        price8[token] = p;
    }

    function setPremium(uint256 bps) external {
        premiumBps = bps;
    }

    function buy(address token, uint256 usdcIn) external returns (uint256 rawOut) {
        usdc.transferFrom(msg.sender, address(this), usdcIn);
        uint256 p = price8[token] * (10_000 + premiumBps) / 10_000;
        uint256 ui = usdcIn * 1e2 * (10 ** IB20Asset(token).decimals()) / p; // usdc 6 dec → 8 dec
        rawOut = IB20Asset(token).fromUIAmount(ui);
        IB20Asset(token).transfer(msg.sender, rawOut);
    }
}

contract MiniVault {
    using SafeERC20 for IERC20;

    error Paused();
    error TokenNotAllowed();
    error ExceedsPerTradeCap();
    error ExceedsDailyCap();
    error StaleOracle();
    error CorporateActionPending(uint256 effectiveAt);
    error AboveFairValue(uint256 paidPrice8, uint256 maxPrice8);
    error ExceedsShareCap(uint256 sharesAfter, uint256 maxShares);
    error OvershootsTarget(address token, uint256 weightAfterBps, uint256 targetBps);

    struct Stock {
        bool allowed;
        MockFeed feed;
        uint16 bandBps;
        uint16 targetBps;
        uint256 maxShares;
    }

    IERC20 public immutable usdc;
    MockSwap public immutable swap;
    address[] public tokens;
    mapping(address => Stock) public stocks;

    bool public paused;
    uint256 public perTradeCap = 100e6;
    uint256 public dailyCap = 250e6;
    uint256 public spentToday;
    uint256 public day;
    uint16 public toleranceBps = 200;
    uint32 public hardStaleLimit = 72 hours;
    bytes32 public researchHash;

    event TradeExecuted(address indexed token, uint256 usdcIn, uint256 sharesAfter, uint256 price8);

    constructor(IERC20 u, MockSwap s) {
        usdc = u;
        swap = s;
    }

    function addStock(address token, MockFeed feed, uint16 targetBps, uint256 maxShares) external {
        tokens.push(token);
        stocks[token] = Stock(true, feed, 100, targetBps, maxShares);
    }

    function setResearchHash(bytes32 h) external {
        researchHash = h;
    }

    function portfolioValue18() public view returns (uint256 v) {
        v = WeightMath.usdcValue18(usdc.balanceOf(address(this)));
        for (uint256 i; i < tokens.length; i++) {
            IB20Asset t = IB20Asset(tokens[i]);
            (, int256 a,,,) = stocks[tokens[i]].feed.latestRoundData();
            v += WeightMath.stockValue18(t.balanceOfUI(address(this)), t.decimals(), uint256(a));
        }
    }

    function weightOf(address token) public view returns (uint256) {
        IB20Asset t = IB20Asset(token);
        (, int256 a,,,) = stocks[token].feed.latestRoundData();
        uint256 part = WeightMath.stockValue18(t.balanceOfUI(address(this)), t.decimals(), uint256(a));
        return WeightMath.weightBps(part, portfolioValue18());
    }

    /// Buy path in SRD section 5 order (steps 1–9 plus the target check).
    function buy(address token, uint256 usdcIn) external {
        if (paused) revert Paused();
        Stock storage s = stocks[token];
        if (!s.allowed) revert TokenNotAllowed();
        if (usdcIn > perTradeCap) revert ExceedsPerTradeCap();
        uint256 d = block.timestamp / 1 days;
        if (d != day) (day, spentToday) = (d, 0);
        if (spentToday + usdcIn > dailyCap) revert ExceedsDailyCap();

        (, int256 a,, uint256 upd,) = s.feed.latestRoundData();
        if (a <= 0 || block.timestamp - upd > hardStaleLimit) revert StaleOracle();
        uint256 eff = IB20Asset(token).effectiveAt();
        if (eff > block.timestamp) revert CorporateActionPending(eff); // never `!= 0` (spike S1)

        uint256 maxPrice8 = uint256(a) * (10_000 + s.bandBps) / 10_000;
        uint8 dec = IB20Asset(token).decimals();
        uint256 before = IB20Asset(token).balanceOfUI(address(this));
        usdc.forceApprove(address(swap), usdcIn);
        swap.buy(token, usdcIn);
        uint256 sharesAfter = IB20Asset(token).balanceOfUI(address(this));
        uint256 got = sharesAfter - before;
        uint256 paid8 = got == 0 ? type(uint256).max : usdcIn * 1e2 * (10 ** dec) / got;
        if (paid8 > maxPrice8) revert AboveFairValue(paid8, maxPrice8);
        if (sharesAfter > s.maxShares) revert ExceedsShareCap(sharesAfter, s.maxShares);

        if (researchHash != bytes32(0)) {
            uint256 w = weightOf(token);
            if (w > s.targetBps + toleranceBps) revert OvershootsTarget(token, w, s.targetBps);
        }
        spentToday += usdcIn;
        emit TradeExecuted(token, usdcIn, sharesAfter, uint256(a));
    }
}
