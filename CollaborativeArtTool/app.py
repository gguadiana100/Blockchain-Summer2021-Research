# Code from https://www.youtube.com/watch?v=mqhxxeeTbu0&ab_channel=TechWithTim

from flask import Flask, redirect, url_for, render_template

# referencing https://eth-brownie.readthedocs.io/en/stable/python-package.html
from brownie import *
print(project.check_for_project('static/nft'))
p = project.load(project.check_for_project('static/nft'))
p.load_config()
from brownie.project import *
network.connect('rinkeby')

# from static.nft.scripts.simple_collectible import deploy_simple

app = Flask(__name__)

@app.route("/")
def home():
    return render_template("index.html")

#background process happening without any refreshing
@app.route('/background_process_test')
def background_process_test():
    print ("Hello starting to deploy script")
    # attempting to run eth-brownie command: brownie run scripts/simple_collectible/deploy_simple.py --network rinkeby
    project.scripts.run('scripts/simple_collectible/deploy_simple.py')
    print("Finished deploying script")
    return ("nothing")

if __name__ == "__main__":
    app.run()
