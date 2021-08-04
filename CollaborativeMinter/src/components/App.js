
import React, { useState } from 'react';
import Web3 from 'web3';
import CollaborativeMinterFactory from '../build/CollaborativeMinterFactory.json'
import CollaborativeMinter from '../build/CollaborativeMinter.json'

const {create} = require('ipfs-http-client')
const ipfs = create({ host: 'ipfs.infura.io', port: '5001', protocol: 'https' }) // use infura public gateway

function App() {

  const [values, setValues] = useState({account: null, buffer: null,
    factoryContract: null, minterContract: null, minterTokenCounter: null}); // set state variables to null

  const captureFile = (event) => { // used to process image for IPFS
    event.preventDefault()
    const file = event.target.files[0]
    console.log(event.target.files[0])
    const reader = new window.FileReader()
    reader.readAsArrayBuffer(file)
    reader.onloadend = () => {
      let oldValues = values;
      oldValues.buffer = Buffer(reader.result)
      setValues(oldValues)
      console.log('buffer', values.buffer)
    }
  }

 const onSubmit = (event) => { // used to send image to IPFS
    event.preventDefault()
    console.log("Submitting file to IPFS...")
    ipfs.add(values.buffer, (error, result) => {
      console.log('IPFS result', result)
      if(error) {
        console.error(error)
        return
      }
    })
  }

  async function componentWillMount(){
    await this.loadWeb3()
    await this.loadBlockchainData()
  }

  async function loadWeb3(){ // connect to MetaMask or other Ethereum provider
    if (window.ethereum){
      window.web3 = new Web3(window.ethereum)
      await window.ethereum.enable()
    }
    else if (window.web3){
      window.web3 = new Web3(window.web3.currentProvider)
    }
    else {
      window.alert('Non-Ethereum browser detected. Try using MetaMask.')
    }
  }

  async function loadBlockchainData (){
    const web3 = window.web3
    // load account
    const accounts = await web3.eth.getAccounts()
    let oldValues = values;
    oldValues.account = accounts[0]
    setValues(oldValues)
    // get info from CollaborativeMinterFactory JSON
    const networkId = await web3.eth.net.getId()
    const networkData = CollaborativeMinterFactory.networks[networkId]

    if(networkData){
      const abi = CollaborativeMinterFactory.abi
      const address = networkData.address
      const factoryContract = new web3.eth.Contract(abi, address)
      console.log(factoryContract)
      const oldValues = values;
      oldValues.factoryContract = factoryContract
      setValues(oldValues)
    }
    else {
      window.alert('The smart contract is not deployed on this network')
    }
  }

  return (
    <>
      <input type="text" />
      <button> Find Game </button>
      <button> Create Game </button>
      <div>
        <form onSubmit={onSubmit}>
          <input type='file' onChange={captureFile} />
          <input type='submit' />
        </form>
      </div>
    </>
  );
}

export default App;
