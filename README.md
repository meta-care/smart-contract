# This is an NFT smart contract with dynamic images. 
## It have the possibility to store data, and to map that data to the corresponding NFT.

Each user can mint one NFT, and the data linked to this user is stored on the smart contract using a mapping and a struct.

There is 3 different metadata possibilities. It is changed by the _tokenURI_ function. If the current heart rate is below 60bpm, a special image appears, is the current heart rate is above 100bpm, another image appears. And if the current heart rate is between these 2 values, a third image appears.

Each user have a doctor, who can see the user data with the _getUserData_ function. The users can see their own data too.

The user can change his doctor's ethereum address with the _changeDoctorAddress_ function.

The users can sell or give their NFTs (because I don't see how can we stop them from doing it) But the functions will not work anymore. The NFT has to be owned by it's creator to make the smart contract work.

The heart Rate of a user can be changed manually using the _changeHeartRate_ function.

An error is thrown if we call a function on an non-existing account.

.

# How to use it:
Deploy it on [Remix](https://remix.ethereum.org/) using a Remix Virtual machine.

    You don't need to use a testnet.
    You don't need to pay or to enter values to create it.

Mint your NFT using the _mint_ function.

    You only need to enter a doctor address. 
    It can be any ETH address you want.
    You don't need to pay to mint it.

You can see your data using the _getUserData_ function.

    You need to enter your wallet address.
    If you are a doctor looking at the data from somebody else: Please enter his wallet address.

You can change your doctor address by using the _changeDoctorAddress_ function.

    You simply have to enter a new doctor ETH address.

You can manually change your heart rate with the _changeHeartRate_ function.

    Since Chainlink is still not implemented, anyone can change the heart rate of anyone else.

You can see your new heart rate or new doctor address by calling the _getUserData_ function.

    You need to enter your wallet address.

.

# Things we need to do on this smart contract :

- Create at least 3 images & metadata + store the link inside
- Adapt it so it can receive data from chainlink
- Only allow chainlink to call the changeHeartRate function.
- Test if the changing image and Chainlink work on a testnet
- We can store any other data, such as: surname, name, age, weight, height...
- Make an Array of Doctors, do not store only one