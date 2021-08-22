
import React, { useState, useEffect, useRef } from 'react';
import Web3 from 'web3';
import CollaborativeMinterFactory from '../build/CollaborativeMinterFactory.json';
import CollaborativeMinter from '../build/CollaborativeMinter.json';
import $ from 'jquery';

const {create} = require('ipfs-http-client')
const ipfs = create({ host: 'ipfs.infura.io', port: '5001', protocol: 'https' }) // use infura public gateway

function App() {

  // initialize state variables
  const [values, setValues] = useState({account: "Connect an ETH account", buffer: "Submit a picture",
    factoryContract: {_address: "Connect a factory contract"},
    cominterContract: {_address: "Connect a cominter contract"},
    cominterTokenCount: "Connect a cominter contract",
    cominterOwners: "Connect a cominter contract",
    cominterTurn: "Connect a cominter contract",
    log: [],
    ipfsHashes: [],
    salesTransactions: [],
  });

  // set references for text boxes
  const findCominterRef = useRef()
  const createCominterRef = useRef()
  const findFactoryRef = useRef()
  const nameSubmit = useRef()
  const descriptionSubmit = useRef()
  const salesTransactionSubmit = useRef()
  const toCreateTransaction = useRef()
  const tokenIdsCreateTransaction = useRef()
  const toTransfer = useRef()
  const tokenIdTransfer = useRef()

  function addToLog (...args) {
    let msg = ""
    for (let i = 0; i < args.length; i++) {
      // create concatenated string of message
      if(typeof args[i] === 'object' && args[i] !== null){ // check for object
        msg = msg + JSON.stringify(args[i])
      }
      else{
        msg = msg + args[i]
      }
    }
    setValues(prevValues => {
      return {...prevValues, log: [...prevValues.log, msg, <br />]}
    })
  }

  // used to process image for IPFS
  const captureFile = (event) => {
    event.preventDefault()
    const file = event.target.files[0]
    addToLog("Starting to process file")
    const reader = new window.FileReader()
    reader.readAsArrayBuffer(file)
    reader.onloadend = () => {
      setValues(prevValues => {
        return {...prevValues, buffer: Buffer(reader.result)}
      })
    }
    addToLog("Finished processing file")
  }
 // used to send image to IPFS and submit to the cominter
 const onFileSubmit = async (event) => {
    event.preventDefault()
    addToLog("Current name: ", nameSubmit.current.value)
    if(values.cominterTurn !== values.account){ // check if it is your turn to submit
      addToLog("It is not your turn")
      return
    }
    addToLog("Submitting file to IPFS...")
    const result = await ipfs.add(values.buffer)
    addToLog("IPFS result of image", result)

    addToLog("Creating collectible")

    const web3 = window.web3
    const cominterContract = values.cominterContract;

    // get the information for the metadata JSON
    const authorDescription = "This stage of the artwork was submitted by " + values.account + ". "
    let imageURL = "https://ipfs.io/ipfs/" + result.path // IPFS URL
    const image = imageURL
    const name = nameSubmit.current.value // get the name input
    const description = authorDescription + descriptionSubmit.current.value // get the description input
    addToLog("Description: ", description)

    // create metadata JSON for IPFS
    const metadataJson = JSON.stringify({
      "description": description,
      "image": image,
      "name": name,
    });

    addToLog("Submitting metadata to IPFS...")
    const metadataResult = await ipfs.add(metadataJson)
    addToLog("IPFS result of metadata: ", metadataResult)

    let metadataUri = "https://ipfs.io/ipfs/" + metadataResult.path
    addToLog(metadataUri)

    // create the collectible
    let newTokenTransaction = await cominterContract.methods.collaborativeMint(metadataUri).send(
      {from: values.account},
      function(error, result){
        return result
      })

    // update the state based on the smart contract values
    const cominterTurnIndex = await cominterContract.methods.currentOwner().call()
    const cominterTurn = await cominterContract.methods.owners(cominterTurnIndex).call()
    const cominterTokenCount = await cominterContract.methods.tokenCounter().call()
    addToLog("Finished creating collectible")

    setValues(prevValues => {
      return {...prevValues,
        ipfsHashes: [...prevValues.ipfsHashes, result.path, metadataResult.path],
        cominterTurn: cominterTurn,
        cominterTokenCount: cominterTokenCount}
    })
  }

  // used to debug IPFS
  const displayLatestIPFS = async (event) => {
    const length = values.ipfsHashes.length

    if(length !== 0){
      const hash = values.ipfsHashes[length-1]
      const path = "https://ipfs.io/ipfs/" + hash // get IPFS URL
      addToLog("The IPFS path to the image is: ", path)

      // create element and add to DOM with IPFS URL as image source
      const image = document.createElement("img")
      image.src = path
      document.body.appendChild(image)

      addToLog("Displaying latest IPFS.")
    }
    else{
      addToLog("No files uploaded to IPFS")
    }
  }

  // find cominter with address
  const handleFindCominter = () => {
    const minterAddress = findCominterRef.current.value
    if(parseInt(minterAddress)) { // check if we have a number
      async function addcominterContract() {
        const web3 = window.web3
        const minterAbi = CollaborativeMinter.abi

        try{
          const cominterContract = new web3.eth.Contract(minterAbi, minterAddress)
          // test to see if the minter contract is valid
          const cominterTurnIndex = await cominterContract.methods.currentOwner().call()
          const cominterTurn = await cominterContract.methods.owners(cominterTurnIndex).call()
          const cominterTokenCount = await cominterContract.methods.tokenCounter().call()
          const cominterNumberOfOwners = await cominterContract.methods.numberOfOwners().call()
          let cominterOwners = []
          for (let i = 0; i < cominterNumberOfOwners; i++) {
            let indexOwner = await cominterContract.methods.owners(i).call()
            cominterOwners.push(indexOwner)
            cominterOwners.push(" ")
          }

          setValues(prevValues => {
            return {...prevValues, cominterContract: cominterContract, cominterTurn: cominterTurn,
              cominterTokenCount: cominterTokenCount, cominterOwners: cominterOwners}
          })
        }
        catch { // smart contract is not on network
          setValues(prevValues => {
            return {...prevValues, cominterContract: {_address: "Input a valid cominter address"}}
          })
        }
      }
      addcominterContract()
    }
    else{
      setValues(prevValues => {
        return {...prevValues, cominterContract: {_address: "Input a valid cominter address"}}
      })
    }
  }

  // find factory with address
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

  // create cominter from list of owners
  const handleCreateCominter = async () => {
    if(values.factoryContract._address === "Connect a factory contract"){
      addToLog("Add a factory contract")
      return
    }

    let _owners

    try{
      _owners = JSON.parse(createCominterRef.current.value)
    }
    catch{
      addToLog("Provide valid input for 'Create Cominter'")
      return
    }

    const web3 = window.web3
    const factoryContract = values.factoryContract;

    // deploy the collaborative minter
    const newCominterAddressTransaction = await factoryContract.methods.createCollaborativeMinter(_owners).send(
      {from: values.account},
      function(error, result){
        return result
      })
    const newCominterIndex = await factoryContract.methods.getNumberOfCollaborativeMinters(values.account).call() - 1
    const newCominterAddressIndex = await factoryContract.methods.accountToCominters(values.account,newCominterIndex).call()
    const newCominterAddress = await factoryContract.methods.collaborativeMinters(newCominterAddressIndex).call()

    const minterAbi = CollaborativeMinter.abi
    const cominterContract = new web3.eth.Contract(minterAbi, newCominterAddress)
    const cominterTurnIndex = await cominterContract.methods.currentOwner().call()
    const cominterTurn = await cominterContract.methods.owners(cominterTurnIndex).call()
    const cominterTokenCount = await cominterContract.methods.tokenCounter().call()
    const cominterNumberOfOwners = await cominterContract.methods.numberOfOwners().call()

    let cominterOwners = []
    for (let i = 0; i < cominterNumberOfOwners; i++) {
      let indexOwner = await cominterContract.methods.owners(i).call()
      cominterOwners.push(indexOwner)
      cominterOwners.push(" ")
    }

    setValues(prevValues => {
      return {...prevValues, cominterContract: cominterContract, cominterTurn: cominterTurn,
        cominterTokenCount: cominterTokenCount, cominterOwners: cominterOwners}
    })

  }

  // get information about cominter
  const handleLoadCominter = async () => {
    if(values.cominterContract._address === "Connect a cominter contract"){
      addToLog("Create a cominter first!")
      return
    }

    const web3 = window.web3
    const factoryContract = values.factoryContract;
    const cominterContract = values.cominterContract

    const numTurns = values.cocominterTokenCount
    let paths = []
    addToLog("Beginning to display tokenURIs")
    for (let i = 0; i < numTurns; i++){ // iterate through the deployed NFTs of the minter
      let uri = await cominterContract.methods.tokenURI(i).call()
      addToLog(uri) // IPFS link to the metadata
      $.getJSON(uri, function(data){
        if(data !== null){
          let imageUrl = data.image
          let turn = document.createElement("p"); // Add sequence of images to the DOM
          let text = "Turn: " + i;
          let turnNumber = document.createTextNode(text);
          turn.appendChild(turnNumber)
          document.body.appendChild(turn);
          let img = document.createElement("img");
          img.src = imageUrl;
          document.body.appendChild(img);
          addToLog(imageUrl)
        }
      })
    }
  }

  const handleMerge = async () => {

  }

  const onTransactionSubmit = async (event) => {
     event.preventDefault()
     switch (document.getElementById("salesTransactionMode").text){
       case "Confirm Transaction":
        confirmTransaction();
       case "Deny Transaction":
        denyTransaction();
       case "Revoke Transaction":
        revokeTransaction();
     }
   }

  const confirmTransaction = async () => {

  }

  const denyTransaction = async () => {

  }

  const revokeTransaction = async () => {

  }

  const onCreateTransaction = async (event) => {
    event.preventDefault()
  }

  const onTransfer = async (event) => {
    event.preventDefault()
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
      async function loadBlockchainData (){ // get ETH account
        const web3 = window.web3
        // load account
        const accounts = await web3.eth.getAccounts()
        setValues(prevValues => {
          return {...prevValues, account: accounts[0]}
        })
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
          <b> Cominter address: </b> {values.cominterContract._address}
          <b> Cominter token count: </b> {values.cocominterTokenCount}
          <b> Cominter turn: </b> {values.cominterTurn}
          <b> Cominter owners: </b> {values.cominterOwners}
        </p>
        <p>
          <b> Loaded picture: </b> {values.buffer}
          <b> IPFS Hashes: </b> {values.ipfsHashes}
        </p>
      </div>

      <div>
        <button onClick={handleFindCominter}> Find cominter with address</button>
        <input type="text" placeholder='cominter address' ref={findCominterRef}/>
        <button onClick={handleFindFactory}> Find factory with address</button>
        <input type="text" placeholder='factory address' ref={findFactoryRef}/>
        <div>
          <br/>
          <button onClick={handleCreateCominter}> Create Cominter </button>
          <input type="text" placeholder='["owner0Address",...]' ref={createCominterRef}/>
          <button onClick={handleLoadCominter}> Load Cominter </button>
        </div>
      </div>

      <div>
        <p>
          <b> Submit to the cominter </b>
        </p>
        <form onSubmit={onFileSubmit}>
          <input type='file' onChange={captureFile} />
          <input type='text' placeholder='name of your work' ref={nameSubmit}/>
          <input type='text' placeholder='description of your work' ref={descriptionSubmit}/>
          <input type='submit' value='Submit your turn'/>
        </form>
         {/* <button style={{ margin: 10 }} onClick={displayLatestIPFS}> Display latest from IPFS </button> */}
         <br/>
         <button onClick={handleMerge}> Merge Collaborative Mint</button>
      </div>

      <div>
        <p>
          <b> Manage Cominter Transactions </b>  <br/> {values.salesTransactions}
        </p>
        <form onSubmit= {onTransactionSubmit}>
          <select id="salesTransactionMode">
            <option> Confirm Transaction </option>
            <option> Deny Transaction </option>
            <option> Revoke Transaction </option>
          </select>
          <input type='text' placeholder='Transaction ID' ref={salesTransactionSubmit}/>
          <input type='submit' value='Submit'/>
        </form>
        <p>
          <b> Create Transaction </b>
        </p>
        <form onSubmit= {onCreateTransaction}>
          <input type='text' placeholder='recipient address' ref={toCreateTransaction}/>
          <input type='text' placeholder='[tokenID1,...]' ref={tokenIdsCreateTransaction}/>
          <input type='submit' value='Submit'/>
        </form>
        <p>
          <b> Transfer Asset </b>
        </p>
        <form onSubmit= {onTransfer}>
          <input type='text' placeholder='recipient address' ref={toTransfer}/>
          <input type='text' placeholder='token ID' ref={tokenIdTransfer}/>
          <input type='submit' value='Submit'/>
        </form>
      </div>

      <div>
        <br/>
        <b> Message Log </b> <br/> {values.log}
      </div>
    </>
  );
}

export default App;
