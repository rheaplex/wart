pragma solidity >= 0.5.0 < 0.7.0;

/* NOTES:
   - We don't use ERC20Burnable as we need to control burns.
*/

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/ownership/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Detailed.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";


contract WrappedArt is
ERC20,
ERC20Detailed('Wrapped Art', 'WART', 0),
Ownable,
ReentrancyGuard
{
    using SafeERC20 for ERC20;
    using SafeMath for uint256;

    event DepositedRareArtAndMintedToken(
        address rareArtContractAddress,
        uint256 rareArtTokenId
    );

    event BurnedTokenAndWithdrewRareArt(
        address rareArtContractAddress,
        uint256 rareArtTokenId
    );
    
    struct DepositedRareArtToken {
        address rareArtContractAddress;
        uint256 rareArtTokenId;
    }

    // The Rare Art ERC721 contracts that we accept tokens from
    mapping(address => bool) public allowedContracts;
    // So we can enumerate wrapped tokens
    DepositedRareArtToken[] public wrappedTokens;
    // So we can specify wrapped tokens independent of enumeration order
    // THESE ARE INDEX + 1!!!!
    mapping(address => mapping(uint256 => uint256)) wrappedTokenPosition;
    
    constructor() public {
        
    }

    function isWrappedToken(
        address rareArtContractAddress,
        uint256 rareArtTokenId
    )
    internal
    returns(
        bool
    )
    {
        return wrappedTokenPosition[rareArtContractAddress][rareArtTokenId]
            != 0;
    }

    function wrappedTokenIndex(
        address rareArtContractAddress,
        uint256 rareArtTokenId
    )
    internal
    returns(
        uint256
    )
    {
        require(
            isWrappedToken(rareArtContractAddress, rareArtTokenId),
            "not a wrapped token"
        );
        return wrappedTokenPosition[rareArtContractAddress][rareArtTokenId];
    }

    function wrapToken(
        address rareArtContractAddress,
        uint256 rareArtTokenId
    )
        internal
    {
        require(
            !isWrappedToken(rareArtContractAddress, rareArtTokenId),
            "already a wrapped token"
        );
        wrappedTokens.push(
            DepositedRareArtToken(
                rareArtContractAddress,
                rareArtTokenId
            )
        );
    }

    function unwrapToken(
        address rareArtContractAddress,
        uint256 rareArtTokenId
    )
        internal
    {
        require(
            isWrappedToken(rareArtContractAddress, rareArtTokenId),
            "not a wrapped token"
        );
        uint256 index
            = wrappedTokenPosition[rareArtContractAddress][rareArtTokenId];
        wrappedTokenPosition[rareArtContractAddress][rareArtTokenId] = 0;
        // If we are not emptying the array or deleting the element at its
        // final index, replace the removed element with the final item.
        if (wrappedTokens.length > 1 && (index != wrappedTokens.length - 1)) {
            wrappedTokens[index] = wrappedTokens[wrappedTokens.length - 1];
            // Point to the new index for the 
            wrappedTokenPosition
                [wrappedTokens[index].rareArtContractAddress]
                [wrappedTokens[index].rareArtTokenId]
                = index;
        }
        wrappedTokens.pop();
    }

    function addRareArtContract(address rareArtContract) external onlyOwner {
        allowedContracts[rareArtContract] = true;
    }

    function removeRareArtContract(address rareArtContract) external onlyOwner {
        allowedContracts[rareArtContract] = false;
    }

    function depositRareArtAndMintTokens(
        address[] calldata rareArtContractAddresses,
        uint256[] calldata rareArtTokenIds
    )
        external
        nonReentrant
    {
        require(
            rareArtTokenIds.length == rareArtContractAddresses.length,
            "arguments must be same length"
        );
        require(
            rareArtContractAddresses.length > 0,
            "you must send at least one token"
        );
        for(uint256 i = 0; i < rareArtContractAddresses.length; i++) {
            require(
                allowedContracts[rareArtContractAddresses[i]] == true,
                "contract not allowed"
            );
            IERC721 erc721 = IERC721(rareArtContractAddresses[i]);
            //FIXME: reentrancy
            erc721.safeTransferFrom(
                msg.sender,
                address(this),
                rareArtTokenIds[i]
            );
            wrapToken(rareArtContractAddresses[i], rareArtTokenIds[i]);
            emit DepositedRareArtAndMintedToken(
                rareArtContractAddresses[i],
                rareArtTokenIds[i]
            );
        }
        _mint(msg.sender, rareArtContractAddresses.length);
    }

    function burnTokensAndWithdrawRareArt(
        address[] calldata rareArtContractAddresses,
        uint256[] calldata rareArtTokenIds,
        address[] calldata recipients
    )
        external
        nonReentrant
    {
        require(
            rareArtTokenIds.length == rareArtContractAddresses.length
            && recipients.length == rareArtContractAddresses.length,
            "arguments must be same length"
        );
        require(
            rareArtContractAddresses.length > 0,
            "you must withdraw > 1 token"
        );
        for (uint256 i = 0; i < rareArtContractAddresses.length; i++) { 
            unwrapToken(rareArtContractAddresses[i], rareArtTokenIds[i]);
            IERC721 erc721 = IERC721(rareArtContractAddresses[i]);
            erc721.safeTransferFrom(
                address(this),
                recipients[i],
                rareArtTokenIds[i]
            );
            emit BurnedTokenAndWithdrewRareArt(
                rareArtContractAddresses[i],
                rareArtTokenIds[i]
            );
        }
        _burn(_msgSender(), rareArtContractAddresses.length);
    }

    //TO ADD: ERC721 Receive function(s)

    //TO ADD: payable function for state rent???
}
