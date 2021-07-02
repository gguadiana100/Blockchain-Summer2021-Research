#!/usr/bin/python3
import os
import requests
import json
from brownie import SimpleCollectible, network
from metadata import sample_metadata
from scripts.helpful_scripts import get_breed
from pathlib import Path
from dotenv import load_dotenv

load_dotenv()

def main():
    print("Working on " + network.show_active())
    # get the latest contract deployment
    simple_collectible = SimpleCollectible[len(SimpleCollectible) - 1]
    # use the counter to get the number of collectibles
    number_of_simple_collectibles = simple_collectible.tokenCounter()
    print(
        "The number of tokens you've deployed is: "
        + str(number_of_simple_collectibles)
    )
    write_metadata(number_of_simple_collectibles, simple_collectible)


def write_metadata(token_ids, nft_contract):
    for token_id in range(token_ids):
        collectible_metadata = sample_metadata.metadata_template
        metadata_file_name = (
            "./metadata/{}/".format(network.show_active())
            + "img"
            + str(token_id)
            + ".json"
        )
        if Path(metadata_file_name).exists(): # check if metadata is already there
            print(
                "{} already found, delete it to overwrite!".format(
                    metadata_file_name)
            )
        else:
            print("Creating Metadata file: " + metadata_file_name)

            # configure the metadata fields
            collectible_metadata["name"] = "Artistic Collaboration # {}".format(
                token_id
            )
            collectible_metadata["description"] = "A fantastic piece of artwork!"

            image_path = "./img/img{}.jpeg".format(token_id)
            image_to_upload = upload_to_ipfs(image_path)

            collectible_metadata["image"] = image_to_upload
            with open(metadata_file_name, "w") as file:
                json.dump(collectible_metadata, file)
            if os.getenv("UPLOAD_IPFS") == "true":
                upload_to_ipfs(metadata_file_name)

# Commands for uploading to IPFS:
# ipfs daemon
# brownie run scripts/simple_collectible/create_metadata.py --network rinkeby

def upload_to_ipfs(filepath):
    with Path(filepath).open("rb") as fp:
        image_binary = fp.read()
        ipfs_url = "http://localhost:5001"
        response = requests.post(ipfs_url + "/api/v0/add",
                                 files={"file": image_binary})
        ipfs_hash = response.json()["Hash"]
        filename = filepath.split("/")[-1:][0]
        image_uri = "https://ipfs.io/ipfs/{}?filename={}".format(
            ipfs_hash, filename)
        print(image_uri)
    return image_uri
