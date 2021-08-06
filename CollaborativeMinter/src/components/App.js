
import React, { useState, useEffect, useRef } from 'react';
import Web3 from 'web3';
import CollaborativeMinterFactory from '../build/CollaborativeMinterFactory.json'
import CollaborativeMinter from '../build/CollaborativeMinter.json'

const {create} = require('ipfs-http-client')
const ipfs = create({ host: 'ipfs.infura.io', port: '5001', protocol: 'https' }) // use infura public gateway

function App() {

  const [values, setValues] = useState({account: "", buffer: "Submit a picture",
    factoryContract: "Connect a factory contract",
    minterContract: {_address: "Connect a cominter contract"},
    minterTokenCount: "Connect a cominter contract",
    cominterTurn: "Connect a cominter contract"}); // set state variables to null

  const findGameRef = useRef()
  const createGameRef = useRef()
  const findFactoryRef = useRef()

  const captureFile = (event) => { // used to process image for IPFS
    event.preventDefault()
    const file = event.target.files[0]
    console.log(event.target.files[0])
    const reader = new window.FileReader()
    reader.readAsArrayBuffer(file)
    reader.onloadend = () => {
      setValues(prevValues => {
        return {...prevValues, buffer: Buffer(reader.result)}
      })
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

  const handleFindGame = () => {
    const minterAddress = findGameRef.current.value
    if(parseInt(minterAddress)) { // check if we have a number
      async function addMinterContract() {
        const web3 = window.web3
        const minterAbi = CollaborativeMinter.abi

        const networkId = await web3.eth.net.getId()
        const networkData = CollaborativeMinter.networks[networkId]

        if(networkData){
          const minterContract = new web3.eth.Contract(minterAbi, minterAddress)
          const currentOwner = await minterContract.methods.currentOwner().call()
          console.log(currentOwner)
          console.log(minterContract)
          setValues( prevValues => {
            return {...prevValues, minterContract: minterContract}
          })
        }
        else { // smart contract is not on network
          setValues(prevValues => {
            return {...prevValues, minterContract: {_address: "Input a valid cominter address"}}
          })
        }
      }
      addMinterContract()
    }
    else{
      setValues(prevValues => {
        return {...prevValues, minterContract: {_address: "Input a valid cominter address"}}
      })
    }
  }

  const handleFindFactory = () => {
    const factoryAddress = findFactoryRef.current.value
    if(parseInt(factoryAddress)) { // check if we have a number
      async function addMinterContract() {
        const web3 = window.web3
        const factoryAbi = CollaborativeMinterFactory.abi

        try{
          const factoryContract = new web3.eth.Contract(factoryAbi, factoryAddress)
          setValues( prevValues => {
            return {...prevValues, factoryContract: factoryContract}
          })
        }
        catch { // smart contract is not on network
          setValues(prevValues => {
            return {...prevValues, minterContract: {_address: "Input a valid cominter address"}}
          })
        }
      }
      addMinterContract()
    }
    else{
      setValues(prevValues => {
        return {...prevValues, minterContract: {_address: "Input a valid cominter address"}}
      })
    }
  }

  const handleCreateGame = async () => {
    if(values.factoryContract === "Connect a factory contract"){
      console.log("add factory contract")
      return
    }

    let _owners

    try{
      _owners = JSON.parse(createGameRef.current.value)
    }
    catch{
      console.log("provide valid input")
      return
    }

    const web3 = window.web3
    const factoryContract = values.factoryContract;

    // deploy the collaborative minter
    const newGameAddressTransaction = await factoryContract.methods.createCollaborativeMinter(_owners).send(
      {from: values.account},
      function(error, result){
        return result
      })
    const newGameIndex = await factoryContract.methods.getNumberOfCollaborativeMinters(values.account).call() - 1
    const newGameAddressIndex = await factoryContract.methods.accountToCominters(values.account,newGameIndex).call()
    const newGameAddress = await factoryContract.methods.collaborativeMinters(newGameAddressIndex).call()

    const minterAbi = CollaborativeMinter.abi
    const minterContract = new web3.eth.Contract(minterAbi, newGameAddress)
    const cominterTurnIndex = await minterContract.methods.currentOwner().call()
    const cominterTurn = await minterContract.methods.owners(cominterTurnIndex).call()
    const minterTokenCount = await minterContract.methods.tokenCounter().call()

    setValues(prevValues => {
      return {...prevValues, minterContract: minterContract, cominterTurn: cominterTurn,
        minterTokenCount: minterTokenCount}
    })

  }

  useEffect(() => { // do once at startup
    async function startup(){
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
        setValues(prevValues => {
          return {...prevValues, account: accounts[0]}
        })
        // get info from CollaborativeMinterFactory JSON
        const networkId = await web3.eth.net.getId()
        const networkData = CollaborativeMinterFactory.networks[networkId]

        if(networkData){
          const abi = CollaborativeMinterFactory.abi
          const address = networkData.address
          const factoryContract = new web3.eth.Contract(abi, address)
          console.log(factoryContract)
          setValues(prevValues => {
            return {...prevValues, factoryContract: factoryContract}
          })
        }
        else {
          window.alert('The smart contract is not deployed on this network')
        }
      }
      await loadWeb3()
      await loadBlockchainData()

    }
    startup()
  },[])

  return (
    <>
      <div>
        <h2>Collaborative Minter</h2>
        <h2> Address: {values.account} </h2>
        <h2> Factory address: {values.factoryContract._address} </h2>
        <h3> Cominter address: {values.minterContract._address} </h3>
        <h3> Cominter token count: {values.minterTokenCount} </h3>
        <h3> Cominter turn: {values.cominterTurn} </h3>
        <h3> Loaded picture: {values.buffer} </h3>
      </div>

      <div>
        <button onClick={handleFindGame}> Find game with address</button>
        <input type="text" placeholder='cominter address' ref={findGameRef}/>
        <button onClick={handleFindFactory}> Find factory with address</button>
        <input type="text" placeholder='factory address' ref={findFactoryRef}/>
        <div style={{ margin: 10 }}>
          <button onClick={handleCreateGame}> Create Game </button>
          <input type="text" placeholder='["owner0Address",...]' ref={createGameRef}/>
        </div>
      </div>

      <div>
        <form onSubmit={onSubmit}>
          <input type='file' onChange={captureFile} />
          <input type='submit' value='Submit Picture'/>
        </form>
      </div>
    </>
  );
}

export default App;
