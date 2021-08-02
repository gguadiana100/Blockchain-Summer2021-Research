
const CollaborativeMinterFactory = artifacts.require('./CollaborativeMinterFactory.sol') // get the smart contract

contract('CollaborativeMinterFactory', (accounts) => {
  let contract

  before(async () => {
    contract = await SimpleCollectible.deployed() // copy of the smart contract
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

    it('has a name', async () => {
      const name = await contract.name()
      console.log(name)
      assert.equal(name,'CollaborativeArt')
    })

    it('has a symbol', async () => {
      const symbol = await contract.symbol()
      console.log(symbol)
      assert.equal(symbol,'CART')
    })

    it('creates a SimpleCollectible', async () => {
      const result = await contract.createCollectible("hi")
      const bigNumberTokenCounter = await contract.tokenCounter() // gives big number format
      const tokenCounter = bigNumberTokenCounter.toNumber()
      console.log(tokenCounter)
      const firstURI = await contract.tokenURI(0)
      console.log(firstURI)
      assert.equal(tokenCounter,1)
      assert.equal(firstURI,"hi")

    })
  })
} )
