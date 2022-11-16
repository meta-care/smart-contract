// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";

error YouAlreadyHaveAnNFT();
error ThisAccountDoesNotExist();
error ThisTokenIdDoesNotExist();
error YouAreNotTheOwnerOfThisNFT();
error YouAreNotAllowedToSeeThisData();
error TheOwnerOfThisNftIsNotHisCreator();
error CreateYourNftBeforeCallingThisFunction();

contract MetaCareNFT is ERC721Enumerable, Ownable, ChainlinkClient {
    using Chainlink for Chainlink.Request;
    using Strings for uint256;

    //URIs storing the metadata for each different NFT states
    string baseURI =
        "https://gateway.pinata.cloud/ipfs/QmNPRHWFYLw5HqQoGaZUkdyoZBjzoEaSatBREQZCFffQfQ/baseURI.png";
    string lowURI =
        "https://gateway.pinata.cloud/ipfs/QmNPRHWFYLw5HqQoGaZUkdyoZBjzoEaSatBREQZCFffQfQ/lowURI.png";
    string highURI =
        "https://gateway.pinata.cloud/ipfs/QmNPRHWFYLw5HqQoGaZUkdyoZBjzoEaSatBREQZCFffQfQ/highURI.png";

    bytes32 private jobId;
    uint256 private linkFee; // 0,1 * 10**18 (Varies by network and job);

    //User Data structure (created during minting, values will be updated automatically)
    struct userData {
        address userAddress;
        address doctorAddress;
        uint256 tokenId;
        uint256 heartRate;
    }

    //create one structure of data for each user (we can find it using the NFT tokenID)
    mapping(address => userData) userDataList;

    //Prepare the smart contract
    constructor(bytes32 _jobId) ERC721("MetaCare", "MC") {
        jobId = _jobId;

        //Work only for goerli testnet :
        setChainlinkToken(0x326C977E6efc84E512bB9C30f76E30c160eD06FB);
        setChainlinkOracle(0xCC79157eb46F5624204f47AB42b3906cAA40eaB7);
        linkFee = (1 * LINK_DIVISIBILITY) / 10; // = 0.1 LINK
    }

    //add yourself to the user list by minting an NFT
    function mint(address _doctorAddress) public {
        if (balanceOf(msg.sender) > 0) {
            revert YouAlreadyHaveAnNFT();
        }

        //Add the user in the struct and create the NFT
        uint256 tokenId = totalSupply() + 1;
        userDataList[msg.sender] = userData(
            msg.sender,
            _doctorAddress,
            tokenId,
            80
        );
        _safeMint(msg.sender, tokenId);
    }

    //Give the possibility to change your doctor's address
    function changeDoctorAddress(address _newDoctorAddress) external {
        if (userDataList[msg.sender].userAddress != msg.sender) {
            revert CreateYourNftBeforeCallingThisFunction();
        }

        if (msg.sender != ownerOf(userDataList[msg.sender].tokenId)) {
            revert TheOwnerOfThisNftIsNotHisCreator();
        }

        //change the doctor address
        userDataList[msg.sender].doctorAddress = _newDoctorAddress;
    }

    //Enter your ETH address or the address of your patient
    function getUserData(address _userAddress)
        external
        returns (userData memory)
    {
        if (userDataList[_userAddress].userAddress != _userAddress) {
            revert ThisAccountDoesNotExist();
        }

        if (_userAddress != ownerOf(userDataList[_userAddress].tokenId)) {
            revert TheOwnerOfThisNftIsNotHisCreator();
        }

        //check if its the user or a doctor who want to see the data
        //Then get data from chainlink, and give the user the current data
        if (
            msg.sender == _userAddress ||
            msg.sender == userDataList[_userAddress].doctorAddress
        ) {
            Chainlink.Request memory req = buildChainlinkRequest(
                jobId,
                address(this),
                this.fulfill.selector
            );
            sendChainlinkRequest(req, linkFee);
            return userDataList[_userAddress];
        }

        //if the person calling the function isn't the data owner or a doctor, send him an error
        revert YouAreNotAllowedToSeeThisData();
    }

    //Get the Metadata for each NFTs
    function tokenURI(uint256 _tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        if (_exists(_tokenId) == false) {
            revert ThisTokenIdDoesNotExist();
        }

        address userAddress = ownerOf(_tokenId);
        if (userDataList[userAddress].userAddress != userAddress) {
            revert ThisAccountDoesNotExist();
        }

        //Get the heartRate of the owner of the tokenID
        uint256 currentHeartRate = userDataList[userAddress].heartRate;

        //Return the URI in function of the current heartRate
        if (currentHeartRate > 100) {
            return highURI;
        } else if (currentHeartRate < 60) {
            return lowURI;
        } else {
            return _baseURI();
        }
    }

    //Define the Base URI
    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }

    //Get Link tokens back from the contract
    function withdrawLink() public onlyOwner {
        LinkTokenInterface link = LinkTokenInterface(chainlinkTokenAddress());
        require(
            link.transfer(msg.sender, link.balanceOf(address(this))),
            "Unable to transfer"
        );
    }

    //function called once chainlink send the data back to the smart contract
    function fulfill(
        bytes32 _requestId,
        address _userAddress,
        uint256 _heartRate
    ) public recordChainlinkFulfillment(_requestId) {
        userDataList[_userAddress].heartRate = _heartRate;
    }
}
