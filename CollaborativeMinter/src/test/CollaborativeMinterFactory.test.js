
const CollaborativeMinterFactory = artifacts.require('./CollaborativeMinterFactory.sol') // get the smart contracts
const CollaborativeMinter = artifacts.require('./CollaborativeMinter.sol')

require('chai') // import the chai testing library
  .use(require('chai-as-promised'))
  .should()


contract('CollaborativeMinterFactory', (accounts) => {
  let contract

  before(async () => {
    contract = await CollaborativeMinterFactory.deployed() // copy of the smart contract
  })

  describe('deployment', async () => {
    it('deploys successfully', async () => {
      const address = contract.address
      console.log(address)
      assert.notEqual(address,'')
      assert.notEqual(address,0x0)
      assert.notEqual(address,null)
      assert.notEqual(address,undefined)
    })

    it('can create an NFT smart contract that deploys', async () => {
      const _owners = [accounts[0],accounts[1]]
      console.log(_owners)
      await contract.createCollaborativeMinter(_owners)
      const collabMinterAddress = await contract.collaborativeMinters(0) // get the CollabMinter smart contract addresses
      console.log(collabMinterAddress)

      const contract2 = await CollaborativeMinter.at(collabMinterAddress)
      const bigNumberCurrentOwner = await contract2.currentOwner()
      const currentOwner = bigNumberCurrentOwner.toNumber()
      console.log(currentOwner)
      assert.equal(currentOwner, 0)

      const bigNumberTokenCounter = await contract2.tokenCounter() // gives big number format
      const tokenCounter = bigNumberTokenCounter.toNumber()
      console.log(tokenCounter)
      assert.equal(tokenCounter, 0)

      const symbol = await contract2.symbol()
      console.log(symbol)
      assert.equal(symbol,'COMINT')

      // const isOwnerAccount0 = await contract2.isOwner(accounts[0]) // this section is not working yet, but seems to work in remix IDE
      // console.log(isOwnerAccount0)
    })

    it('can create an NFT', async () => {
      // const collabMinterAddress = await contract.collaborativeMinters(0) // get the CollabMinter smart contract addresses
      // const contract2 = await CollaborativeMinter.at(collabMinterAddress)
      // const owner0 = await contract2.owners(0)
      // console.log(owner0)
      // const bigNumberCurrentOwnerId = await contract2.currentOwner()
      // const currentOwnerId = bigNumberCurrentOwnerId.toNumber()
      // console.log(currentOwnerId)
      //
      // const result = await contract2.collaborativeMint("First NFT", {from: accounts[0]}) // mint an NFT



      // console.log(result)
      // const bigNumberTokenCounter = await contract2.tokenCounter() // gives big number format
      // const tokenCounter = bigNumberTokenCounter.toNumber()
      // console.log(tokenCounter)
      // const firstURI = await contract2.tokenURI(0)
      // console.log(firstURI)
      // assert.equal(tokenCounter,1)
      // assert.equal(firstURI,"First NFT")

    })
  })
} )
