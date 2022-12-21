// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import "./Base64.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

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

    //Prepare the smart contract when its creation
    constructor(bytes32 _jobId) ERC721("MetaCare Health", "MC") {
        jobId = _jobId;

        //Work only for goerli testnet :
        setChainlinkToken(0x326C977E6efc84E512bB9C30f76E30c160eD06FB);
        setChainlinkOracle(0xCC79157eb46F5624204f47AB42b3906cAA40eaB7);
        linkFee = (1 * LINK_DIVISIBILITY) / 10; // = 0.1 LINK
    }

    /////////////////////////////////// USER FUNCTIONS ///////////////////////////////////

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
        view
        returns (userData memory)
    {
        if (userDataList[_userAddress].userAddress != _userAddress) {
            revert ThisAccountDoesNotExist();
        }

        if (_userAddress != ownerOf(userDataList[_userAddress].tokenId)) {
            revert TheOwnerOfThisNftIsNotHisCreator();
        }

        //check if its the user or a doctor who want to see the data
        if (
            msg.sender == _userAddress ||
            msg.sender == userDataList[_userAddress].doctorAddress
        ) {
            return userDataList[_userAddress];
        }

        //if the person calling the function isn't the data owner or a doctor, send him an error
        revert YouAreNotAllowedToSeeThisData();
    }

    /////////////////////////////////// UTILITY FUNCTIONS ///////////////////////////////////

    //Get data from chainlink
    function requestHeartRate(string memory _userAddress) external {
        Chainlink.Request memory req = buildChainlinkRequest(
            jobId,
            address(this),
            this.fulfill.selector
        );
        req.add("userAddress", _userAddress);
        sendChainlinkRequest(req, linkFee);
    }

    //function called once chainlink send the data back to the smart contract
    function fulfill(
        bytes32 _requestId,
        address _userAddress,
        uint256 _heartRate
    ) public recordChainlinkFulfillment(_requestId) {
        userDataList[_userAddress].heartRate = _heartRate;
    }

    //cancel a chainlink request
    function cancelRequest(
        bytes32 _requestId,
        uint256 _payment,
        bytes4 _callbackFunctionId,
        uint256 _expiration
    ) public onlyOwner {
        cancelChainlinkRequest(
            _requestId,
            _payment,
            _callbackFunctionId,
            _expiration
        );
    }

    //Get the Metadata for each NFTs
    function tokenURI(
        uint256 _tokenId
    ) public view virtual override returns (string memory) {
        if (_exists(_tokenId) == false) {
            revert ThisTokenIdDoesNotExist();
        }

        address userAddress = ownerOf(_tokenId);
        if (userDataList[userAddress].userAddress != userAddress) {
            revert ThisAccountDoesNotExist();
        }

        //Get the heartRate of the owner of the tokenID
        uint256 currentHeartRate = userDataList[userAddress].heartRate;

        //Return the Heart rate level in function of the current heartRate
        string memory heartRateLevel;
        string memory color;
        string memory text;
        if (currentHeartRate > 100) {
            heartRateLevel = "High";
            color = "da0b4a";
            text = "Above 100 bpm";
        } else if (currentHeartRate < 60) {
            heartRateLevel = "Low";
            color = "f78517";
            text = "Below 60 bpm";
        } else {
            heartRateLevel = "Normal";
            color = "2370b9";
            text = "Normal Heart Rate";
        }

        return
            string(
                abi.encodePacked(
                    "data:application/json;base64,",
                    Base64.encode(
                        bytes(
                            abi.encodePacked(
                                '{"name":"',
                                heartRateLevel,
                                " Heart Rate",
                                '", "description": "The patient resting heart rate is ',
                                heartRateLevel,
                                ". This is not an official medical diagnosis and your heart rate should be monitored by a certified instrument. Please consult your doctor if you feel any chest pain.",
                                '", "attributes": [{ "trait-type": "Heart Rate","value": "',
                                heartRateLevel,
                                '"}], "image": "',
                                "data:image/svg+xml;base64,",
                                Base64.encode(
                                    bytes(
                                        abi.encodePacked(
                                            '<svg width="800" height="800" xmlns="http://www.w3.org/2000/svg" fill="none">',
                                            '<rect fill="#',
                                            color,
                                            '" height="800" width="800"/>',
                                            '<path d="m176,669.74562l-4.127,2.374l-11.246,6.502l-4.127,2.374l0,22.5l4.127,2.374l11.349,6.502l4.127,2.374l4.127,-2.374l11.143,-6.502l4.127,-2.374l0,-22.5l-4.127,-2.374l-11.246,-6.502l-4.127,-2.374zm-11.246,29.002l0,-13.004l11.246,-6.503l11.246,6.503l0,13.004l-11.246,6.503l-11.246,-6.503z" fill="white"/>',
                                            '<path d="m264.86,352.87762c-3.19,-22.325 2.278,-44.651 20.051,-62.753c16.558,-16.744 40.559,-29.566 68.965,-23.231c23.09,5.129 37.977,21.27 44.053,29.567c1.367,1.81 4.101,1.81 5.468,0c6.229,-8.146 20.963,-24.287 44.053,-29.567c28.406,-6.335 52.407,6.487 68.965,23.231c44.812,45.255 10.937,116.908 -38.128,149.944c-20.204,13.577 -50.889,35.148 -65.168,49.026c-4.101,3.922 -7.443,7.542 -9.874,10.408c-1.367,1.509 -3.645,1.509 -5.012,0c-2.431,-2.866 -5.773,-6.486 -9.874,-10.408c-14.279,-13.727 -45.116,-35.299 -65.168,-49.026c-17.165,-11.615 -29.773,-23.532 -40.558,-41.785" stroke="white" stroke-width="10" stroke-miterlimit="10" stroke-linecap="round" stroke-linejoin="round"/>',
                                            '<path d="m271.236,376.41262l40.255,0l12,-19.309l16.254,43.596l19.14,-96.695l22.027,125.205l27.495,-76.631l16.405,48.422l14.583,-24.588l37.521,0" stroke="white" stroke-width="10" stroke-miterlimit="10" stroke-linecap="round" stroke-linejoin="round"/>',
                                            '<path d="m476.913,388.32562c6.626,0 11.997,-5.335 11.997,-11.917c0,-6.581 -5.371,-11.917 -11.997,-11.917c-6.626,0 -11.997,5.336 -11.997,11.917c0,6.582 5.371,11.917 11.997,11.917z" fill="white"/>',
                                            '<path fill="white" d="m254.251,113.628l0,60.372l-14.706,0l0,-36.206l-13.502,36.206l-11.868,0l-13.588,-36.292l0,36.292l-14.706,0l0,-60.372l17.372,0l16.942,41.796l16.77,-41.796l17.286,0zm55.811,35.604c0,1.376 -0.086,2.809 -0.258,4.3l-33.282,0c0.229,2.981 1.175,5.275 2.838,6.88c1.72,1.548 3.813,2.322 6.278,2.322c3.669,0 6.221,-1.548 7.654,-4.644l15.652,0c-0.803,3.153 -2.265,5.991 -4.386,8.514c-2.064,2.523 -4.673,4.501 -7.826,5.934c-3.153,1.433 -6.679,2.15 -10.578,2.15c-4.701,0 -8.887,-1.003 -12.556,-3.01c-3.669,-2.007 -6.536,-4.873 -8.6,-8.6c-2.064,-3.727 -3.096,-8.084 -3.096,-13.072c0,-4.988 1.003,-9.345 3.01,-13.072c2.064,-3.727 4.931,-6.593 8.6,-8.6c3.669,-2.007 7.883,-3.01 12.642,-3.01c4.644,0 8.772,0.975 12.384,2.924c3.612,1.949 6.421,4.73 8.428,8.342c2.064,3.612 3.096,7.826 3.096,12.642zm-15.05,-3.87c0,-2.523 -0.86,-4.529 -2.58,-6.02c-1.72,-1.491 -3.87,-2.236 -6.45,-2.236c-2.465,0 -4.558,0.717 -6.278,2.15c-1.663,1.433 -2.695,3.469 -3.096,6.106l18.404,0zm49.554,16.168l0,12.47l-7.482,0c-5.332,0 -9.488,-1.29 -12.47,-3.87c-2.981,-2.637 -4.472,-6.909 -4.472,-12.814l0,-19.092l-5.848,0l0,-12.212l5.848,0l0,-11.696l14.706,0l0,11.696l9.632,0l0,12.212l-9.632,0l0,19.264c0,1.433 0.344,2.465 1.032,3.096c0.688,0.631 1.835,0.946 3.44,0.946l5.246,0zm5.268,-11.61c0,-4.931 0.917,-9.259 2.752,-12.986c1.892,-3.727 4.443,-6.593 7.654,-8.6c3.21,-2.007 6.794,-3.01 10.75,-3.01c3.382,0 6.335,0.688 8.858,2.064c2.58,1.376 4.558,3.182 5.934,5.418l0,-6.794l14.706,0l0,47.988l-14.706,0l0,-6.794c-1.434,2.236 -3.44,4.042 -6.02,5.418c-2.523,1.376 -5.476,2.064 -8.858,2.064c-3.899,0 -7.454,-1.003 -10.664,-3.01c-3.211,-2.064 -5.762,-4.959 -7.654,-8.686c-1.835,-3.784 -2.752,-8.141 -2.752,-13.072zm35.948,0.086c0,-3.669 -1.032,-6.565 -3.096,-8.686c-2.007,-2.121 -4.472,-3.182 -7.396,-3.182c-2.924,0 -5.418,1.061 -7.482,3.182c-2.007,2.064 -3.01,4.931 -3.01,8.6c0,3.669 1.003,6.593 3.01,8.772c2.064,2.121 4.558,3.182 7.482,3.182c2.924,0 5.389,-1.061 7.396,-3.182c2.064,-2.121 3.096,-5.017 3.096,-8.686zm22.851,-6.278c0,-5.963 1.29,-11.266 3.87,-15.91c2.58,-4.701 6.163,-8.342 10.75,-10.922c4.644,-2.637 9.89,-3.956 15.738,-3.956c7.167,0 13.301,1.892 18.404,5.676c5.103,3.784 8.514,8.944 10.234,15.48l-16.168,0c-1.204,-2.523 -2.924,-4.443 -5.16,-5.762c-2.179,-1.319 -4.673,-1.978 -7.482,-1.978c-4.529,0 -8.199,1.577 -11.008,4.73c-2.809,3.153 -4.214,7.367 -4.214,12.642c0,5.275 1.405,9.489 4.214,12.642c2.809,3.153 6.479,4.73 11.008,4.73c2.809,0 5.303,-0.659 7.482,-1.978c2.236,-1.319 3.956,-3.239 5.16,-5.762l16.168,0c-1.72,6.536 -5.131,11.696 -10.234,15.48c-5.103,3.727 -11.237,5.59 -18.404,5.59c-5.848,0 -11.094,-1.29 -15.738,-3.87c-4.587,-2.637 -8.17,-6.278 -10.75,-10.922c-2.58,-4.644 -3.87,-9.947 -3.87,-15.91zm65.078,6.192c0,-4.931 0.917,-9.259 2.752,-12.986c1.892,-3.727 4.443,-6.593 7.654,-8.6c3.21,-2.007 6.794,-3.01 10.75,-3.01c3.382,0 6.335,0.688 8.858,2.064c2.58,1.376 4.558,3.182 5.934,5.418l0,-6.794l14.706,0l0,47.988l-14.706,0l0,-6.794c-1.434,2.236 -3.44,4.042 -6.02,5.418c-2.523,1.376 -5.476,2.064 -8.858,2.064c-3.899,0 -7.454,-1.003 -10.664,-3.01c-3.211,-2.064 -5.762,-4.959 -7.654,-8.686c-1.835,-3.784 -2.752,-8.141 -2.752,-13.072zm35.948,0.086c0,-3.669 -1.032,-6.565 -3.096,-8.686c-2.007,-2.121 -4.472,-3.182 -7.396,-3.182c-2.924,0 -5.418,1.061 -7.482,3.182c-2.007,2.064 -3.01,4.931 -3.01,8.6c0,3.669 1.003,6.593 3.01,8.772c2.064,2.121 4.558,3.182 7.482,3.182c2.924,0 5.389,-1.061 7.396,-3.182c2.064,-2.121 3.096,-5.017 3.096,-8.686zm40.051,-15.996c1.72,-2.637 3.87,-4.701 6.45,-6.192c2.58,-1.548 5.447,-2.322 8.6,-2.322l0,15.566l-4.042,0c-3.669,0 -6.421,0.803 -8.256,2.408c-1.835,1.548 -2.752,4.3 -2.752,8.256l0,22.274l-14.706,0l0,-47.988l14.706,0l0,7.998zm67.315,15.222c0,1.376 -0.086,2.809 -0.258,4.3l-33.282,0c0.229,2.981 1.175,5.275 2.838,6.88c1.72,1.548 3.813,2.322 6.278,2.322c3.669,0 6.221,-1.548 7.654,-4.644l15.652,0c-0.803,3.153 -2.265,5.991 -4.386,8.514c-2.064,2.523 -4.673,4.501 -7.826,5.934c-3.153,1.433 -6.679,2.15 -10.578,2.15c-4.701,0 -8.887,-1.003 -12.556,-3.01c-3.669,-2.007 -6.536,-4.873 -8.6,-8.6c-2.064,-3.727 -3.096,-8.084 -3.096,-13.072c0,-4.988 1.003,-9.345 3.01,-13.072c2.064,-3.727 4.931,-6.593 8.6,-8.6c3.669,-2.007 7.883,-3.01 12.642,-3.01c4.644,0 8.772,0.975 12.384,2.924c3.612,1.949 6.421,4.73 8.428,8.342c2.064,3.612 3.096,7.826 3.096,12.642zm-15.05,-3.87c0,-2.523 -0.86,-4.529 -2.58,-6.02c-1.72,-1.491 -3.87,-2.236 -6.45,-2.236c-2.465,0 -4.558,0.717 -6.278,2.15c-1.663,1.433 -2.695,3.469 -3.096,6.106l18.404,0z"/>',
                                            '<text text-anchor="middle" font-size="36" y="88%" x="50%" fill="#ffffff">Medical data encrypted</text>',
                                            '<text text-anchor="middle" font-size="66" y="79%" x="50%" fill="#ffffff">',
                                            text,
                                            "</text>",
                                            "</svg>"
                                        )
                                    )
                                ),
                                '"}'
                            )
                        )
                    )
                )
            );
    }

    //Get Link tokens back from the contract
    function withdrawLink() public onlyOwner {
        LinkTokenInterface link = LinkTokenInterface(chainlinkTokenAddress());
        require(
            link.transfer(msg.sender, link.balanceOf(address(this))),
            "Unable to transfer"
        );
    }

    function withdrawBalance() public onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }

    function setJobId(bytes32 _jobId) public onlyOwner {
        jobId = _jobId;
    }
}
