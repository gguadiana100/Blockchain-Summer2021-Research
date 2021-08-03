
const CollaborativeMinterFactory = artifacts.require('./CollaborativeMinterFactory.sol') // get the smart contract

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
      console.log(accounts[0])
      const NftSmartContract = await contract.createCollaborativeMinter(_owners)
      const address = NftSmartContract.address
      console.log(NftSmartContract)
      console.log(address)
      // assert.notEqual(address,'')
      // assert.notEqual(address,0x0)
      // assert.notEqual(address,null)
      // assert.notEqual(address,undefined)
    })

    // it('has a symbol', async () => {
    //   const symbol = await contract.symbol()
    //   console.log(symbol)
    //   assert.equal(symbol,'CART')
    // })
    //
    // it('creates a SimpleCollectible', async () => {
    //   const result = await contract.createCollectible("hi")
    //   const bigNumberTokenCounter = await contract.tokenCounter() // gives big number format
    //   const tokenCounter = bigNumberTokenCounter.toNumber()
    //   console.log(tokenCounter)
    //   const firstURI = await contract.tokenURI(0)
    //   console.log(firstURI)
    //   assert.equal(tokenCounter,1)
    //   assert.equal(firstURI,"hi")
    //
    // })
  })
} )
