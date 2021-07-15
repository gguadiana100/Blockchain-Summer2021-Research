# this file aims to add token URI metadata to the tokenURI JSON file
# it does this by
import json
from scripts.simple_collectible import create_metadata

def main():
    # read tokenURI JSON object
    a_file = open("./static/nft/tokenURI/tokenURI.json", "r")
    json_object = json.load(a_file)
    a_file.close()

    tokenArray = create_metadata.main() # get back the latest tokenURI, tokenID, metadata file name
    if tokenArray[0] != None: # adding JSON element if metadata was created
        tokenID = tokenArray[0]
        tokenURI = tokenArray[1]
        metadataFileName = tokenArray[2]

        json_object[tokenID] = tokenURI
        a_file = open("./tokenURI/tokenURI.json", "w")
        json.dump(json_object, a_file)
        a_file.close()
        return tokenURI
    else:
        print(tokenArray)
        print("tokenURI is already present or there is no image file")
        return None
