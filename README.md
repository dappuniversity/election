/Users/williamdoody/dev/election/contracts/Election.sol:1:1: SyntaxError: Source file requires different compiler version (current compiler is 0.4.24+commit.e67f0147.Emscripten.clang - note that nightly builds are considered to be strictly less than the released version
pragma solidity 0.4.20;
^---------------------^
,/Users/williamdoody/dev/election/contracts/Election.sol:24:5: Warning: Defining constructors as functions with the same name as the contract is deprecated. Use "constructor(...) { ... }" instead.
    function Election () public {
    ^ (Relevant source part starts here and spans across multiple lines).
,/Users/williamdoody/dev/election/contracts/Migrations.sol:11:3: Warning: Defining constructors as functions with the same name as the contract is deprecated. Use "constructor(...) { ... }" instead.
  function Migrations() {
  ^ (Relevant source part starts here and spans across multiple lines).
,/Users/williamdoody/dev/election/contracts/Election.sol:48:9: Warning: Invoking events without "emit" prefix is deprecated.
        votedEvent(_candidateId);
        ^----------------------^
Compilation failed. See above.
Williams-MBP:election williamdoody$ 





# Election - DAPP Tutorial
Build your first decentralized application, or Dapp, on the Ethereum Network with this tutorial!

**Full Free Video Tutorial:**
https://youtu.be/3681ZYbDSSk


Follow the steps below to download, install, and run this project.

## Dependencies
Install these prerequisites to follow along with the tutorial. See free video tutorial or a full explanation of each prerequisite.
- NPM: https://nodejs.org
- Truffle: https://github.com/trufflesuite/truffle
- Ganache: http://truffleframework.com/ganache/
- Metamask: https://metamask.io/


## Step 1. Clone the project
`git clone https://github.com/dappuniversity/election`

## Step 2. Install dependencies
```
$ cd election
$ npm install
```
## Step 3. Start Ganache
Open the Ganache GUI client that you downloaded and installed. This will start your local blockchain instance. See free video tutorial for full explanation.


## Step 4. Compile & Deploy Election Smart Contract
`$ truffle migrate --reset`
You must migrate the election smart contract each time your restart ganache.

## Step 5. Configure Metamask
See free video tutorial for full explanation of these steps:
- Unlock Metamask
- Connect metamask to your local Etherum blockchain provided by Ganache.
- Import an account provided by ganache.

## Step 6. Run the Front End Application
`$ npm run dev`
Visit this URL in your browser: http://localhost:3000

If you get stuck, please reference the free video tutorial.

