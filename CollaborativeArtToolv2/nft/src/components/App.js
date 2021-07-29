import React, { Component } from 'react';
import Web3 from 'web3';
import './App.css';
import SimpleCollectible from '../abis/SimpleCollectible.json'
import BigNumber from "bignumber.js";

class App extends Component {

  async componentWillMount(){
    await this.loadWeb3()
    await this.loadBlockchainData()
  }

  async loadWeb3(){ // connect to MetaMask or other Ethereum provider
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

  async loadBlockchainData(){
    const web3 = window.web3
    // load account
    const accounts = await web3.eth.getAccounts()
    this.setState({account: accounts[0]})
    // get info from SimpleCollectible JSON
    const networkId = await web3.eth.net.getId()
    const networkData = SimpleCollectible.networks[networkId]

    if(networkData){
      const abi = SimpleCollectible.abi
      const address = networkData.address
      const contract = new web3.eth.Contract(abi, address)
      console.log(contract)
      this.setState({contract:contract})
      var tokenCounter = await contract.methods.tokenCounter().call()
      tokenCounter = tokenCounter.toNumber()
      this.setState({tokenCounter: tokenCounter})
    }
    else {
      window.alert('The smart contract is not deployed on this network')
    }

  }

  mint = (simpleCollectible) => {
    console.log(simpleCollectible)
    this.state.contract.methods.createCollectible(simpleCollectible).send({from: this.state.account})
    .once('receipt',(receipt)=>{
      this.setState({doneMinting: true})
    })
  }

  constructor(props) {
    super(props);
    this.state = {
      account: '',
      contract: null,
      tokenCounter: null,
      doneMinting: false,
      simpleCollectibles: [],
    };
  }

  render() {
    return (
      <div>
        <nav className="navbar navbar-light bg-light">
          <div className="container-fluid">
            <a className="navbar-brand" href="./#">Collaborative Art Tool v2</a>
            <p> Ethereum Account: {this.state.account}</p>
          </div>
        </nav>
        <div className="container-fluid mt-5">
          <div className="row">
            <main role="main" className="col-lg-12 d-flex text-center">
              <div className="content mr-auto ml-auto">
                <h1>Issue NFT</h1>
                <form onSubmit={(event) => {
                  event.preventDefault()
                  const simpleCollectible = this.simpleCollectible.value
                  this.mint(simpleCollectible)
                }}>
                  <input
                    type='text'
                    className='form-control mb-1'
                    placeholder='example'
                    ref={(input)=>{this.simpleCollectible = input}}
                  />
                  <input
                    type='submit'
                    className='btn btn-block btn-primary'
                    placeholder='MINT NFT'
                  />
                </form>
              </div>
            </main>
          </div>
        </div>
      </div>
    );
  }
}

export default App;
