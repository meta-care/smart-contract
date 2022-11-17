# This is an NFT smart contract with dynamic images. 
## It have the possibility to store data, and to map that data to the corresponding NFT.

Each user can mint one NFT, and the data linked to this user is stored on the smart contract using a mapping and a struct.

There is 3 different metadata possibilities. It is changed by the _tokenURI_ function. If the current heart rate is below 60bpm, a special image appears, is the current heart rate is above 100bpm, another image appears. And if the current heart rate is between these 2 values, a third image appears.

Each user have a doctor, who can see the user data with the _getUserData_ function. The users can see their own data too.

The user can change his doctor's ethereum address with the _changeDoctorAddress_ function.

The users can sell or give their NFTs. But the functions will not work anymore. The NFT has to be owned by it's creator to make the smart contract work.

An error is thrown if we call a function on an non-existing account.

To request data from chainlink, use the requestHeartRate function. It will be possible to automate it later.

.

# How to use it:

Deploy it on Goerli with [Remix](https://remix.ethereum.org/)

    Enter the jobId

Mint your NFT using the _mint_ function.

    Enter your doctor's ETH address. 
    You don't need to pay to mint it.

Send some [Link token](https://faucets.chain.link/) to the smart contract.

Request data from chainlink with the _requestHeartRate_ function.

    You need to enter your wallet address. 

You can see your data using the _getUserData_ function.

    You need to enter your wallet address.
    If you are a doctor looking at the data from somebody else: Please enter his wallet address.

You can change your doctor address by using the _changeDoctorAddress_ function.

    You simply have to enter a new doctor ETH address.
