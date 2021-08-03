
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

      const symbol = await contract2.symbol()
      console.log(symbol)
      assert.equal(symbol,'COMINT')
    })
  })
} )
