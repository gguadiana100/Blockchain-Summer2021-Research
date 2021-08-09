
import React, { useState, useEffect, useRef } from 'react';
import Web3 from 'web3';
import CollaborativeMinterFactory from '../build/CollaborativeMinterFactory.json'
import CollaborativeMinter from '../build/CollaborativeMinter.json'

const {create} = require('ipfs-http-client')
const ipfs = create({ host: 'ipfs.infura.io', port: '5001', protocol: 'https' }) // use infura public gateway

function App() {

  const [values, setValues] = useState({account: "Connect an ETH account", buffer: "Submit a picture",
    factoryContract: {_address: "Connect a factory contract"},
    minterContract: {_address: "Connect a cominter contract"},
    minterTokenCount: "Connect a cominter contract",
    minterOwners: [],
    cominterTurn: "Connect a cominter contract",
    ipfsHashes: [],}); // set state variables to null

  const findGameRef = useRef()
  const createGameRef = useRef()
  const findFactoryRef = useRef()
  const nameSubmit = useRef()

  const captureFile = (event) => { // used to process image for IPFS
    event.preventDefault()
    const file = event.target.files[0]
    console.log("Starting to process:", event.target.files[0])
    const reader = new window.FileReader()
    reader.readAsArrayBuffer(file)
    reader.onloadend = () => {
      setValues(prevValues => {
        return {...prevValues, buffer: Buffer(reader.result)}
      })
    }
    console.log("Finished processing file")
  }

 const onSubmit = async (event) => { // used to send image to IPFS
    event.preventDefault()
    if(values.cominterTurn != values.account){ // check if it is your turn to submit
      console.log("It is not your turn")
      return
    }
    console.log("Submitting file to IPFS...")
    const result = await ipfs.add(values.buffer)
    console.log("IPFS result of image", result)

    console.log("Creating collectible")

    const web3 = window.web3
    const minterContract = values.minterContract;

    // get the information for the metadata JSON
    const description = "This stage of the artwork was submitted by " + values.account
    let imageURL = "https://ipfs.io/ipfs/" + result.path // IPFS URL
    const image = imageURL
    const name = nameSubmit.current.value // get the name input

    const metadataJson = JSON.stringify({
      "description": description,
      "image": image,
      "name": name,
    });

    console.log("Submitting metadata to IPFS...")
    const metadataResult = await ipfs.add(metadataJson)
    console.log("IPFS result of metadata", metadataResult)

    let metadataUri = "https://ipfs.io/ipfs/" + metadataResult.path
    console.log(metadataUri)
    let newTokenTransaction = await minterContract.methods.collaborativeMint(metadataUri).send( // create the collectible
      {from: values.account},
      function(error, result){
        return result
      })

    // update the state based on the smart contract values
    const cominterTurnIndex = await minterContract.methods.currentOwner().call()
    const cominterTurn = await minterContract.methods.owners(cominterTurnIndex).call()
    const minterTokenCount = await minterContract.methods.tokenCounter().call()
    console.log("Finished creating collectible")

    setValues(prevValues => {
      return {...prevValues,
        ipfsHashes: [...prevValues.ipfsHashes, result.path, metadataResult.path],
        cominterTurn: cominterTurn,
        minterTokenCount: minterTokenCount}
    })
  }

  const displayLatestIPFS = async (event) => {
    const length = values.ipfsHashes.length

    if(length !== 0){
      const hash = values.ipfsHashes[length-1]
      const path = "https://ipfs.io/ipfs/" + hash // get IPFS URL
      console.log("The IPFS path to the image is: ", path)

      // create element and add to DOM with IPFS URL as image source
      const image = document.createElement("img")
      image.src = path
      document.body.appendChild(image)

      console.log("Displaying latest IPFS.")
    }
    else{
      console.log("No files uploaded to IPFS")
    }
  }

  const handleFindGame = () => {
    const minterAddress = findGameRef.current.value
    if(parseInt(minterAddress)) { // check if we have a number
      async function addMinterContract() {
        const web3 = window.web3
        const minterAbi = CollaborativeMinter.abi

        try{
          const minterContract = new web3.eth.Contract(minterAbi, minterAddress)
          // test to see if the minter contract is valid
          const cominterTurnIndex = await minterContract.methods.currentOwner().call()
          const cominterTurn = await minterContract.methods.owners(cominterTurnIndex).call()
          const minterTokenCount = await minterContract.methods.tokenCounter().call()

          setValues(prevValues => {
            return {...prevValues, minterContract: minterContract, cominterTurn: cominterTurn,
              minterTokenCount: minterTokenCount}
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

  const handleFindFactory = () => {
    const factoryAddress = findFactoryRef.current.value
    if(parseInt(factoryAddress)) { // check if we have a number
      async function addFactoryContract() {
        const web3 = window.web3
        const factoryAbi = CollaborativeMinterFactory.abi

        try{
          const factoryContract = new web3.eth.Contract(factoryAbi, factoryAddress)
          // test to see if the factory contract is valid
          factoryContract.methods.collaborativeMinters(0).call()
          setValues( prevValues => {
            return {...prevValues, factoryContract: factoryContract}
          })
        }
        catch { // smart contract is not on network
          setValues(prevValues => {
            return {...prevValues, factoryContract: {_address: "Input a valid factory address"}}
          })
        }
      }
      addFactoryContract()
    }
    else{
      setValues(prevValues => {
        return {...prevValues, factoryContract: {_address: "Input a valid factory address"}}
      })
    }
  }

  const handleCreateGame = async () => {
    if(values.factoryContract._address === "Connect a factory contract"){
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

  const handleLoadGame = async () => {
    if(values.minterContract._address === "Connect a cominter contract"){
      console.log("Create a game first!")
      return
    }

    const web3 = window.web3
    const factoryContract = values.factoryContract;
    const minterContract = values.minterContract

    const numTurns = values.tokenCounter
    let paths = []
    for (let i = 0; i < numTurns; i++){ // iterate through the deployed NFTs of the minter
      let uri = await minterContract.methods.tokenURI(i).call()
      console.log(uri)
      // let hash = 0
      // let path = "https://ipfs.io/ipfs/" + hash
    }

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
        // const networkId = await web3.eth.net.getId()
        // const networkData = CollaborativeMinterFactory.networks[networkId]
        //
        // if(networkData){
        //   const abi = CollaborativeMinterFactory.abi
        //   const address = networkData.address
        //   const factoryContract = new web3.eth.Contract(abi, address)
        //   console.log(factoryContract)
        //   setValues(prevValues => {
        //     return {...prevValues, factoryContract: factoryContract}
        //   })
        // }
        // else {
        //   window.alert('The smart contract is not deployed on this network')
        // }
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

        <p>
          <b> User Address: </b> {values.account}
          <b> Factory address: </b> {values.factoryContract._address}
        </p>

        <p>
          <b> Cominter address: </b> {values.minterContract._address}
          <b> Cominter token count: </b> {values.minterTokenCount}
          <b> Cominter turn: </b> {values.cominterTurn}
        </p>
        <p>
          <b> Loaded picture: </b> {values.buffer}
          <b> IPFS Hashes: </b> {values.ipfsHashes}
        </p>
      </div>

      <div>
        <button onClick={handleFindGame}> Find game with address</button>
        <input type="text" placeholder='cominter address' ref={findGameRef}/>
        <button onClick={handleFindFactory}> Find factory with address</button>
        <input type="text" placeholder='factory address' ref={findFactoryRef}/>
        <div style={{ margin: 10 }}>
          <button onClick={handleCreateGame}> Create Game </button>
          <input type="text" placeholder='["owner0Address",...]' ref={createGameRef}/>
          <button onClick={handleLoadGame}> Load Game </button>
        </div>
      </div>

      <div>
        <p>
          <b> Submit to the game </b>
        </p>
        <form onSubmit={onSubmit}>
          <input type='file' onChange={captureFile} />
          <input type='text' placeholder='name of your work' ref={nameSubmit}/>
          <input type='submit' value='Submit your turn'/>
        </form>
        <button style={{ margin: 10 }} onClick={displayLatestIPFS}> Display latest from IPFS </button>
      </div>
    </>
  );
}

export default App;
