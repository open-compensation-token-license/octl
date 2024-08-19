// SPDX-License-Identifier: UNLICENSE
// Copyright 2024, Tim Frey, Christian Schmitt
// License Open Compensation Token License https://github.com/open-compensation-token-license/license
// @octl.sid 7dec4673-5559-4895-9714-1cdd61a58b57

pragma solidity ^0.8.0;
import "./ILicenseFeeDirective.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "../octl.sol";

//TODO: Add the necessary things to enable the dynamic computation
contract DefaultLicenseFeeDirective is
    ILicenseFeeDirective,
    Initializable,
    AccessControlUpgradeable,
    UUPSUpgradeable
{
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address defaultAdmin,
        address upgrader
    ) public initializer {
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);

        _grantRole(UPGRADER_ROLE, upgrader);
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyRole(UPGRADER_ROLE) {}

    function computeLicenseCosts(
        uint256 storyPoints,
        bytes calldata computationDetails,
        int256[] calldata variables
    ) public pure override returns (uint256 amount) {
        // TODO create an expression with variables

        return storyPoints * 50 * (uint256(variables[0]));
    }

    // $p is stroy points in the expression
    function calculateExpression(
        string memory input,
        int256[] memory variables,
        int256 storyPoints
    ) internal pure returns (int256) {
        bytes memory inputBytes = bytes(input);
        int256[] memory tokens = new int256[](0);
        bytes1[] memory operators = new bytes1[](0);

        for (uint i = 0; i < inputBytes.length; i++) {
            bytes1 c = inputBytes[i];
            if (c == bytes1(" ")) {
                continue;
            } else if (c == bytes1("(")) {
                operators = pushToOperators(operators, c);
            } else if (c == bytes1(")")) {
                while (
                    operators.length > 0 &&
                    operators[operators.length - 1] != bytes1("(")
                ) {
                    int256 b = tokens[tokens.length - 1];
                    int256 a = tokens[tokens.length - 2];
                    bytes1 op = operators[operators.length - 1];
                    int256 result = calculate(a, b, op);
                    tokens = popFromTokens(tokens);
                    tokens = popFromTokens(tokens);
                    tokens = pushToTokens(tokens, result);
                    operators = popFromOperators(operators);
                }
                operators = popFromOperators(operators); // Pop '('
            } else if (c == bytes1("^")) {
                // Handle exponentiation
                operators = pushToOperators(operators, c);
            } else if (
                c == bytes1("+") ||
                c == bytes1("-") ||
                c == bytes1("*") ||
                c == bytes1("/") ||
                c == bytes1("%")
            ) {
                while (
                    operators.length > 0 &&
                    hasPrecedence(c, operators[operators.length - 1])
                ) {
                    int256 b = tokens[tokens.length - 1];
                    int256 a = tokens[tokens.length - 2];
                    bytes1 op = operators[operators.length - 1];
                    int256 result = calculate(a, b, op);
                    tokens = popFromTokens(tokens);
                    tokens = popFromTokens(tokens);
                    tokens = pushToTokens(tokens, result);
                    operators = popFromOperators(operators);
                }
                operators = pushToOperators(operators, c);
            } else if (c == bytes1("$")) {
                // array element
                // check c+1 for the number
                i++;
                if (inputBytes[i] == bytes1("p")) {
                    // if it is $p it is story points
                    i++;
                    tokens = pushToTokens(tokens, storyPoints);
                } else {
                    int indexVariable = 0;
                    while (
                        i < inputBytes.length &&
                        uint8(inputBytes[i]) >= 48 &&
                        uint8(inputBytes[i]) <= 57
                    ) {
                        indexVariable =
                            indexVariable *
                            10 +
                            int(uint(uint8(inputBytes[i]) - 48));
                        i++;
                    }

                    tokens = pushToTokens(
                        tokens,
                        variables[uint256(indexVariable)]
                    );
                }
            } else {
                // number
                int256 number = 0;
                bool isNegative = false;

                if (
                    c == bytes1("-") &&
                    (i == 0 || inputBytes[i - 1] == bytes1("("))
                ) {
                    // Handle negative numbers
                    isNegative = true;
                    i++;
                }

                while (
                    i < inputBytes.length &&
                    uint8(inputBytes[i]) >= 48 &&
                    uint8(inputBytes[i]) <= 57
                ) {
                    number =
                        number *
                        10 +
                        int256(uint(uint8(inputBytes[i]) - 48));
                    i++;
                }
                i--;

                if (isNegative) {
                    number = -number;
                }

                tokens = pushToTokens(tokens, number);
            }
        }

        while (operators.length > 0) {
            int256 b = tokens[tokens.length - 1];
            int256 a = tokens[tokens.length - 2];
            bytes1 op = operators[operators.length - 1];
            int256 result = calculate(a, b, op);
            tokens = popFromTokens(tokens);
            tokens = popFromTokens(tokens);
            tokens = pushToTokens(tokens, result);
            operators = popFromOperators(operators);
        }

        require(tokens.length == 1, "Invalid expression");
        return tokens[0];
    }

    function pushToOperators(
        bytes1[] memory operators,
        bytes1 item
    ) private pure returns (bytes1[] memory) {
        bytes1[] memory newOperators = new bytes1[](operators.length + 1);
        for (uint i = 0; i < operators.length; i++) {
            newOperators[i] = operators[i];
        }
        newOperators[operators.length] = item;
        return newOperators;
    }

    function popFromOperators(
        bytes1[] memory operators
    ) private pure returns (bytes1[] memory) {
        require(operators.length > 0, "Operators underflow");
        bytes1[] memory newOperators = new bytes1[](operators.length - 1);
        for (uint i = 0; i < newOperators.length; i++) {
            newOperators[i] = operators[i];
        }
        return newOperators;
    }

    function pushToStack(
        bytes32[] memory stack,
        bytes1 item
    ) private pure returns (bytes32[] memory) {
        bytes32[] memory newStack = new bytes32[](stack.length + 1);
        for (uint i = 0; i < stack.length; i++) {
            newStack[i] = stack[i];
        }
        newStack[stack.length] = bytes32(item);
        return newStack;
    }

    function popFromStack(
        bytes32[] memory stack
    ) private pure returns (bytes32[] memory) {
        require(stack.length > 0, "Stack underflow");
        bytes32[] memory newStack = new bytes32[](stack.length - 1);
        for (uint i = 0; i < newStack.length; i++) {
            newStack[i] = stack[i];
        }
        return newStack;
    }

    function pushToTokens(
        int256[] memory tokens,
        int256 item
    ) private pure returns (int[] memory) {
        int256[] memory newTokens = new int256[](tokens.length + 1);
        for (uint i = 0; i < tokens.length; i++) {
            newTokens[i] = tokens[i];
        }
        newTokens[tokens.length] = item;
        return newTokens;
    }

    function popFromTokens(
        int[] memory tokens
    ) private pure returns (int256[] memory) {
        require(tokens.length > 0, "Tokens underflow");
        int256[] memory newTokens = new int256[](tokens.length - 1);
        for (uint i = 0; i < newTokens.length; i++) {
            newTokens[i] = tokens[i];
        }
        return newTokens;
    }

    /**
     * @notice Checks if one operator has precedence over another.
     * @param op1 The first operator.
     * @param op2 The second operator.
     * @return True if op1 has precedence over op2, false otherwise.
     */
    function hasPrecedence(bytes1 op1, bytes1 op2) private pure returns (bool) {
        if (op2 == bytes1("(") || op2 == bytes1(")")) {
            return false;
        }
        if (
            (op1 == bytes1("*") ||
                op1 == bytes1("/") ||
                op1 == bytes1("^") ||
                op1 == bytes1("%")) &&
            (op2 == bytes1("+") || op2 == bytes1("-"))
        ) {
            return false;
        } else {
            return true;
        }
    }

    /**
     * @notice Performs a calculation with two unsigned integers and an operator.
     * @param a The first unsigned integer.
     * @param b The second unsigned integer.
     * @param op The operator (+, -, *, /, ^, %).
     * @return The result of the calculation as an unsigned integer (uint).
     */
    function calculate(
        int256 a,
        int256 b,
        bytes1 op
    ) private pure returns (int256) {
        if (op == bytes1("+")) {
            return a + b;
        } else if (op == bytes1("-")) {
            return a - b;
        } else if (op == bytes1("*")) {
            return a * b;
        } else if (op == bytes1("/")) {
            require(b != 0, "Cannot divide by zero");
            return a / b;
        } else if (op == bytes1("^")) {
            int256 result = 1;
            for (int256 i = 0; i < b; i++) {
                result *= a;
            }
            return result;
        } else if (op == bytes1("%")) {
            require(b != 0, "Cannot modulo by zero");
            return a % b;
        }
        revert("Invalid operator");
    }

    /**
     * @notice Extracts variables (unsigned integers) from an input byte string.
     * @param inputBytes The input byte string.
     * @return An array of extracted unsigned integers.
     */
    function extractVariables(
        bytes memory inputBytes
    ) public pure returns (uint8[] memory) {
        uint8[] memory xNumbers = new uint8[](inputBytes.length); // Maximum possible number of x numbers
        uint8 xNumberCount = 0;
        uint8 currentNumber = 0;
        bool isParsingXNumber = false;

        for (uint i = 0; i < inputBytes.length; i++) {
            if (isParsingXNumber) {
                if (
                    inputBytes[i] >= bytes1("0") && inputBytes[i] <= bytes1("9")
                ) {
                    currentNumber =
                        currentNumber *
                        10 +
                        uint8(inputBytes[i]) -
                        uint8(bytes1("0"));
                } else {
                    xNumbers[xNumberCount++] = currentNumber;
                    currentNumber = 0;
                    isParsingXNumber = false;
                }
            }

            if (inputBytes[i] == bytes1("x")) {
                isParsingXNumber = true;
            }
        }

        // If an x number is at the end of the string
        if (isParsingXNumber) {
            xNumbers[xNumberCount++] = currentNumber;
        }

        // Resize the xNumbers array to the actual number of x numbers
        assembly {
            mstore(xNumbers, xNumberCount)
        }

        return xNumbers;
    }

    /**
     * @notice Removes variable tokens (unsigned integers) from an input byte string.
     * @param inputBytes The input byte string.
     * @return The modified input byte string with variables removed.
     */
    function removeXNumbers(
        bytes memory inputBytes
    ) public pure returns (bytes memory) {
        bytes memory resultBytes = new bytes(inputBytes.length);
        uint resultLength = 0;

        for (uint i = 0; i < inputBytes.length; i++) {
            if (inputBytes[i] == bytes1("x")) {
                // Skip the "x" character
                resultBytes[resultLength++] = inputBytes[i];
                i++;
                // Skip the digits following "x"
                while (
                    i < inputBytes.length &&
                    inputBytes[i] >= bytes1("0") &&
                    inputBytes[i] <= bytes1("9")
                ) {
                    i++;
                }
                // Move the index back by one to handle the character after "x" properly
                i--;
            } else {
                resultBytes[resultLength++] = inputBytes[i];
            }
        }

        // Trim the resultBytes to the actual length
        bytes memory result = new bytes(resultLength);
        for (uint j = 0; j < resultLength; j++) {
            result[j] = resultBytes[j];
        }

        return result;
    }
}
