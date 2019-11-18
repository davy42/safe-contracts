pragma solidity >=0.5.0 <0.7.0;
pragma experimental ABIEncoderV2;
import "../base/Module.sol";


import { Account } from "../lib/Account.sol";
import { Actions } from "../lib/Actions.sol";
import { Types } from "../lib/Types.sol";



contract ICErc20 {
    function redeem(uint redeemTokens) external returns (uint);
    function mint(uint mintAmount) external returns (uint);
}

contract ISolo {
    function operate(Account.Info[] memory accounts, Actions.ActionArgs[] memory actions) public;
}


/// @title Daily Limit Module - Allows to transfer limited amounts of ERC20 tokens and Ether without confirmations.
/// @author Stefan George - <stefan@gnosis.pm>
contract LendingMoveModule is Module {

    string public constant NAME = "Lending Move Module";
    string public constant VERSION = "0.1.0";

    ICErc20 CompoundContract;
    address SoloContract;

    struct Market {
        uint256 soloId;
        address cToken;
    }

    mapping(address => Market) markers;

    enum ProtocolType{DYDX, Compound}

    /// @dev Setup function sets initial storage of contract.
    function setup()
        public
    {
        setManager();
        // Dai
        markers[address(0x89d24A6b4CcB1B6fAA2625fE562bDD9a23260359)] = Market({
            soloId: uint256(1),
            cToken: address(0xF5DCe57282A584D2746FaF1593d3121Fcac444dC)
        });

        // USDc
        markers[address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48)] = Market({
            soloId: uint256(2),
            cToken: address(0x39AA39c021dfbaE8faC545936693aC917d5E7563)
        });
    }

    function executeMove(address token, ProtocolType protocolFrom, ProtocolType protocolTo, uint256 amount) public {
        Market memory market = markers[token];
        if (protocolFrom == ProtocolType.Compound && protocolTo == ProtocolType.DYDX) {
            ICErc20(market.cToken).redeem(amount);
            soloDeposit(amount, market.soloId);


        } else if (protocolFrom == ProtocolType.DYDX && protocolTo == ProtocolType.Compound) {
            soloWithdraw(amount, market.soloId);
            ICErc20(market.cToken).mint(amount);
        }
    }

    function soloDeposit(uint256 amount, uint256 marketId) internal {
        Types.AssetAmount memory _amount = getAssetAmount(amount);
        Account.Info[] memory accounts = getAccountInfo();
        Actions.ActionArgs[] memory actions = getAction(Actions.ActionType.Withdraw, _amount, marketId);
        ISolo(SoloContract).operate(accounts, actions);
    }

    function soloWithdraw(uint256 amount, uint256 marketId) internal {
        Types.AssetAmount memory _amount = getAssetAmount(amount);
        Account.Info[] memory accounts = getAccountInfo();
        Actions.ActionArgs[] memory actions = getAction(Actions.ActionType.Withdraw, _amount, marketId);
        ISolo(SoloContract).operate(accounts, actions);
    }

    function getAssetAmount(uint256 amount) internal pure returns(Types.AssetAmount memory) {
        Types.AssetAmount memory _amount = Types.AssetAmount({
            sign: true,
            denomination: Types.AssetDenomination.Wei,
            ref: Types.AssetReference.Target,
            value: amount
        });
        return _amount;
    }

    function getAccountInfo() internal view returns(Account.Info[] memory) {
        Account.Info memory account = Account.Info({owner: msg.sender,number: 1});
        Account.Info[] memory accounts;
        accounts[0] = account;
        return accounts;
    }

    function getAction(Actions.ActionType _action, Types.AssetAmount memory _amount, uint256 marketId) internal view returns(Actions.ActionArgs[] memory){
        Actions.ActionArgs memory action = Actions.ActionArgs({
                actionType: _action,
                accountId: 0,
                amount: _amount,
                primaryMarketId: marketId,
                secondaryMarketId: 0,
                otherAddress: msg.sender,
                otherAccountId: 0,
                data: "0x"
            });

        Actions.ActionArgs[] memory actions;
        actions[0] = action;
        return actions;
    }

}
