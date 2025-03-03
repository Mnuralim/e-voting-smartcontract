// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract SoulBoundTest is ERC721, ERC721URIStorage, Ownable {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;
    mapping(address => bool) private _hasMinted;
    mapping(uint256 => string) private _faculty;
    mapping(uint256 => string) private _program;
    mapping(uint256 => string) private _image;

    error AlreadyMinted();
    error TransferBlocked();
    error NFTNotFound();

    constructor() ERC721("WhitelistSoulBound", "WSBT") {}

    function safeMint(
        address to,
        string memory uri,
        string memory faculty,
        string memory program,
        string memory image
    ) public onlyOwner {
        if (_hasMinted[to]) {
            revert AlreadyMinted();
        }
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
        _hasMinted[to] = true;
        _faculty[tokenId] = faculty;
        _program[tokenId] = program;
        _image[tokenId] = image;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override {
        if (from != address(0)) {
            revert TransferBlocked();
        }
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function _burn(
        uint256 tokenId
    ) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function totalMinted() public view returns (uint256) {
        return _tokenIdCounter.current();
    }

    function tokenURI(
        uint256 tokenId
    ) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function getNFTData(
        address owner
    )
        public
        view
        returns (
            string memory faculty,
            string memory program,
            string memory image,
            string memory uri
        )
    {
        if (balanceOf(owner) <= 0) {
            revert NFTNotFound();
        }
        uint256 tokenId = tokenOfOwnerByIndex(owner, 0);
        faculty = _faculty[tokenId];
        program = _program[tokenId];
        image = _image[tokenId];
        uri = tokenURI(tokenId);
    }

    function tokenOfOwnerByIndex(
        address owner,
        uint256 index
    ) public view returns (uint256) {
        require(index < balanceOf(owner), "Owner index out of bounds");
        uint256 tokenId;
        uint256 count;
        for (uint256 i = 0; i < _tokenIdCounter.current(); i++) {
            if (_exists(i) && ownerOf(i) == owner) {
                if (count == index) {
                    tokenId = i;
                    break;
                }
                count++;
            }
        }
        return tokenId;
    }
}
