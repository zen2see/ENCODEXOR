// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;
pragma experimental ABIEncoderV3;

import {LibStrings} from "../../shared/libraries/LibStrings.sol";
import {AppStorage} from "../libraries/LibAppStorage.sol";
import {LibMeta} from "../../shared/libraries/LibMeta.sol";
import "https://github.com/Uniswap/uniswap-v3-periphery/blob/main/contracts/interfaces/ISwapRouter.sol";
import "https://github.com/Uniswap/uniswap-v3-periphery/blob/main/contracts/interfaces/IQuoter.sol";

contract EncodexorFacet { 
    AppStorage internal s;

    function uniswapV3Call(
        address _sender,
        uint _amount0, 
        uint _amount1, 
        bytes calldata _data
    )
    external                                
    view
    {
        address[] memory path = new address[](2);
        uint amountToken = _amount0 == 0 ? _amount1 : _amount0;
        address token0 = IUniswapV3Pair(msg.sender).token0();
        address token1 = IUniswapV3Pair(msg.sender).token1();
        require(msg.sender == UniswapV3Library.pairFor(s.factory, token0, token1), "Unauthorized");
        require(_amount0 == 0 || _amount1 == 0);
        path[0] = _amount0 == 0 ? token1 : token0;
        path[1] = _amount1 == 0 ? token0 : token1;
        IERC20 token = IERC20(_amount0 == 0 ? token1 : token0);
        token.approve(address(s.sushiRouter), amountToken);
        // no need for require() check, if amount required is not sent sushiRouter will revert
        uint amountRequired = UniswapV3Library.getAmountsIn(s.factory, amountToken, path)[0];
        uint amountReceived  = s.sushiRouter.swapExactTokensForTokens(
            amountToken, 
            amountRequired, 
            path, 
            msg.sender,
            s.deadline)[1];
            // YEAH PROFIT!
            token.transfer(_sender, amountReceived - amountRequired);
    }

    function totalSupply() external view returns (uint256 totalSupply_) {
        totalSupply_ = s.tokenIds.length;
    }

    /// @notice Count all NFTs assigned to an owner
    /// @dev NFTs assigned to the zero address are considered invalid, and this.
    ///  function throws for queries about the zero address.
    /// @param _owner An address for whom to query the balance
    /// @return balance_ The number of NFTs owned by `_owner`, possibly zero
    function balanceOf(address _owner) external view returns (uint256 balance_) {
        require(_owner != address(0), "EncodexorFacet: _owner can't be address(0");
        balance_ = s.ownerTokenIds[_owner].length;
    }

    function getrbitrageur(uint256 _tokenId) external view returns (EncodexorInfo memory EncodexorInfo_) {
        EncodexorInfo_ = LibEncodexor.getEncodexor(_tokenId);
    }

    // /// @notice Enumerate valid NFTs
    // /// @dev Throws if `_index` >= `totalSupply()`.
    // /// @param _index A counter less than `totalSupply()`
    // /// @return The token identifier for the `_index`th NFT,
    // ///  (sort order not specified)
    function tokenByIndex(uint256 _index) external view returns (uint256 tokenId_) {
        require(_index < s.tokenIds.length, "EncodexorFacet: index beyond supply");
        tokenId_ = s.tokenIds[_index];
    }

    // /// @notice Enumerate NFTs assigned to an owner
    // /// @dev Throws if `_index` >= `balanceOf(_owner)` or if
    // ///  `_owner` is the zero address, representing invalid NFTs.
    // /// @param _owner An address where we are interested in NFTs owned by them
    // /// @param _index A counter less than `balanceOf(_owner)`
    // /// @return The token identifier for the `_index`th NFT assigned to `_owner`,
    // ///   (sort order not specified)
    function tokenOfOwnerByIndex(address _owner, uint256 _index) external view returns (uint256 tokenId_) {
        require(_index < s.ownerTokenIds[_owner].length, "EncodexorFacet: index beyond owner balance");
        tokenId_ = s.ownerTokenIds[_owner][_index];
    }

    function tokenIdsOfOwner(address _owner) external view returns (uint32[] memory tokenIds_) {
        tokenIds_ = s.ownerTokenIds[_owner];
    }

    function allEncodexorsOfOwner(address _owner) external view returns (EncodexorInfo[] memory EncodexorInfos_) {
        uint256 length = s.ownerTokenIds[_owner].length;
        EncodexorInfos_ = new EncodexorInfo[](length);
        for (uint256 i; i < length; i++) {
            EncodexorInfos_[i] = LibEncodexor.getEncodexor(s.ownerTokenIds[_owner][i]);
        }
    }

    /// @notice Find the owner of an NFT
    /// @dev NFTs assigned to zero address are considered invalid, and queries
    ///  about them do throw.
    /// @param _tokenId The identifier for an NFT
    /// @return owner_ The address of the owner of the NFT
    function ownerOf(uint256 _tokenId) external view returns (address owner_) {
        owner_ = s.Encodexors[_tokenId].owner;
        require(owner_ != address(0), "EncodexorFacet: invalid _tokenId");
    }

    /// @notice Get the approved address for a single NFT
    /// @dev Throws if `_tokenId` is not a valid NFT.
    /// @param _tokenId The NFT to find the approved address for
    /// @return approved_ The approved address for this NFT, or the zero address if there is none
    function getApproved(uint256 _tokenId) external view returns (address approved_) {
        require(_tokenId < s.tokenIds.length, "ERC721: tokenId is invalid");
        approved_ = s.approved[_tokenId];
    }

    /// @notice Query if an address is an authorized operator for another address
    /// @param _owner The address that owns the NFTs
    /// @param _operator The address that acts on behalf of the owner
    /// @return approved_ True if `_operator` is an approved operator for `_owner`, false otherwise
    function isApprovedForAll(address _owner, address _operator) external view returns (bool approved_) {
        approved_ = s.operators[_owner][_operator];
    }

    /// @notice Transfers the ownership of an NFT from one address to another address
    /// @dev Throws unless `LibMeta.msgSender()` is the current owner, an authorized
    ///  operator, or the approved address for this NFT. Throws if `_from` is
    ///  not the current owner. Throws if `_to` is the zero address. Throws if
    ///  `_tokenId` is not a valid NFT. When transfer is complete, this function
    ///  checks if `_to` is a smart contract (code size > 0). If so, it calls
    ///  `onERC721Received` on `_to` and throws if the return value is not
    ///  `bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"))`.
    /// @param _from The current owner of the NFT
    /// @param _to The new owner
    /// @param _tokenId The NFT to transfer
    /// @param _data Additional data with no specified format, sent in call to `_to`
    function safeTransferFrom(
        address _from,
        address _to,
        uint256 _tokenId,
        bytes calldata _data
    ) external {
        address sender = LibMeta.msgSender();
        internalTransferFrom(sender, _from, _to, _tokenId);
        LibERC721.checkOnERC721Received(sender, _from, _to, _tokenId, _data);
    }

    /// @notice Transfers the ownership of an NFT from one address to another address
    /// @dev This works identically to the other function with an extra data parameter,
    ///  except this function just sets data to "".
    /// @param _from The current owner of the NFT
    /// @param _to The new owner
    /// @param _tokenId The NFT to transfer
    function safeTransferFrom(
        address _from,
        address _to,
        uint256 _tokenId
    ) external {
        address sender = LibMeta.msgSender();
        internalTransferFrom(sender, _from, _to, _tokenId);
        LibERC721.checkOnERC721Received(sender, _from, _to, _tokenId, "");
    }

    /// @notice Transfer ownership of an NFT -- THE CALLER IS RESPONSIBLE
    ///  TO CONFIRM THAT `_to` IS CAPABLE OF RECEIVING NFTS OR ELSE
    ///  THEY MAY BE PERMANENTLY LOST
    /// @dev Throws unless `LibMeta.msgSender()` is the current owner, an authorized
    ///  operator, or the approved address for this NFT. Throws if `_from` is
    ///  not the current owner. Throws if `_to` is the zero address. Throws if
    ///  `_tokenId` is not a valid NFT.
    /// @param _from The current owner of the NFT
    /// @param _to The new owner
    /// @param _tokenId The NFT to transfer
    function transferFrom(
        address _from,
        address _to,
        uint256 _tokenId
    ) external {
        internalTransferFrom(LibMeta.msgSender(), _from, _to, _tokenId);
    }

    // This function is used by transfer functions
    function internalTransferFrom(
        address _sender,
        address _from,
        address _to,
        uint256 _tokenId
    ) internal {
        require(_to != address(0), "EncodexorFacet: Can't transfer to 0 address");
        require(_from != address(0), "EncodexorFacet: _from can't be 0 address");
        require(_from == s.Encodexors[_tokenId].owner, "EncodexorFacet: _from is not owner, transfer failed");
        require(
            _sender == _from || s.operators[_from][_sender] || _sender == s.approved[_tokenId],
            "EncodexorFacet: Not owner or approved to transfer"
        );
        LibEncodexor.transfer(_from, _to, _tokenId);
        LibERC721Marketplace.updateERC721Listing(address(this), _tokenId, _from);
    }

}