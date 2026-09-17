// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title Wilson score lower bound, in WAD
/// @notice A raw success rate is a liar on small samples. Three wins out of three
///         is 100%, and it tells you nothing. The Wilson lower bound asks instead:
///         given this record, what is the worst true success rate still consistent
///         with it at 95% confidence? Three-for-three scores about 0.29. A record of
///         650/1000 scores about 0.62 and outranks it, which is the correct ordering.
///
///         This matters here because reputation gates money. An agent that can farm
///         a perfect score from a handful of cheap mandates would be able to rent
///         out that score. Making the bound widen on thin evidence removes the
///         incentive to do it.
library Wilson {
    uint256 internal constant WAD = 1e18;

    /// z = 1.96 (95% confidence), and z squared, both in WAD.
    uint256 internal constant Z = 1.96e18;
    uint256 internal constant Z2 = 3.8416e18;

    /// @param passed number of settled mandates the agent met
    /// @param failed number of settled mandates the agent missed
    /// @return lower bound of the 95% confidence interval, in WAD (1e18 == 100%)
    function score(uint256 passed, uint256 failed) internal pure returns (uint256) {
        uint256 n = passed + failed;
        if (n == 0) return 0;

        // With no successes the bound is exactly zero: the centre and the margin
        // both reduce to z^2/2n and cancel. Returning early avoids leaving the
        // integer-rounding dust that the cancellation would otherwise produce.
        if (passed == 0) return 0;

        uint256 p = (passed * WAD) / n;

        // centre = p + z^2 / 2n
        uint256 centre = p + Z2 / (2 * n);

        // inner = ( p(1-p) + z^2 / 4n ) / n
        uint256 variance = (p * (WAD - p)) / WAD;
        uint256 inner = (variance + Z2 / (4 * n)) / n;

        // margin = z * sqrt(inner)
        uint256 margin = (Z * sqrtWad(inner)) / WAD;

        // An agent with no successes can produce a centre below the margin.
        // The bound is clamped at zero rather than underflowing.
        if (centre <= margin) return 0;

        uint256 denominator = WAD + Z2 / n;
        return ((centre - margin) * WAD) / denominator;
    }

    /// @notice sqrt of a WAD-scaled number, returned WAD-scaled.
    /// @dev sqrt(x * 1e18) keeps the result in WAD. x is at most 1e18 here, so
    ///      x * 1e18 is at most 1e36 and cannot overflow.
    function sqrtWad(uint256 x) internal pure returns (uint256) {
        return sqrt(x * WAD);
    }

    /// @notice Babylonian square root.
    function sqrt(uint256 x) internal pure returns (uint256 y) {
        if (x == 0) return 0;
        uint256 z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }
}
