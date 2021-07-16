#!/usr/bin/python3
from brownie import SimpleCollectible, accounts, network, config
from scripts.helpful_scripts import OPENSEA_FORMAT
from scripts.simple_collectible import add_tokenuri

sample_token_uri = "https://ipfs.io/ipfs/Qmd9MCGtdVz2miNumBHDbvj8bigSgTwnr4SbyH6DNnpWdt?filename=0-PUG.json"

def main():
    dev = accounts.add(config["wallets"]["from_key"])
    print("Working on " + network.show_active())
    simple_collectible = SimpleCollectible[len(SimpleCollectible) - 1] # get the latest NFT smart contract deployment
    token_id = simple_collectible.tokenCounter() # get the count
    print(
        "The number of tokens you've deployed so far is: "
        + str(token_id)
    )

    tokenURI = add_tokenuri.main()
    # display the tokenURI if you have it
    if tokenURI != None:
        print("Here is the tokenURI: {}").format(tokenURI)
    else:
        print("No tokenURI")
    transaction = simple_collectible.createCollectible(tokenURI, {"from": dev})
    transaction.wait(1)
    print(
        "Awesome! You can view your NFT at {}".format(
            OPENSEA_FORMAT.format(simple_collectible.address, token_id)
        )
    )
    print('Please give up to 20 minutes, and hit the "refresh metadata" button')
