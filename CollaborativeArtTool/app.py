# Code from https://www.youtube.com/watch?v=mqhxxeeTbu0&ab_channel=TechWithTim

from flask import Flask, redirect, url_for, render_template

# referencing https://eth-brownie.readthedocs.io/en/stable/python-package.html
from brownie import *
print(project.check_for_project('static/nft'))
p = project.load(project.check_for_project('static/nft'))
p.load_config()
from brownie.project import *
# set to test network Rinkeby
network.connect('rinkeby')

# from static.nft.scripts.simple_collectible import deploy_simple

app = Flask(__name__)

@app.route("/")
def home():
    return render_template("index.html")

# background process happening without any refreshing
# deploying nft contract without refreshing
# referencing https://stackoverflow.com/questions/42601478/flask-calling-python-function-on-button-onclick-event
@app.route('/deploy_nft_script')
def deploy_nft_script():
    print ("Hello starting to deploy script")
    # attempting to run eth-brownie command: brownie run scripts/simple_collectible/deploy_simple.py --network rinkeby
    project.scripts.run('scripts/simple_collectible/deploy_simple.py')
    print("Finished deploying script")
    return ("nothing")

# mint the nft
@app.route('/mint_nft_script')
def mint_nft_script():
    print ("Beginning to mint NFT with script")
    # attempting to run eth-brownie command: brownie run scripts/simple_collectible/deploy_simple.py --network rinkeby
    project.scripts.run('scripts/simple_collectible/create_collectible.py')
    print("Finished minting NFT with script")
    return ("nothing")

if __name__ == "__main__":
    app.run()
