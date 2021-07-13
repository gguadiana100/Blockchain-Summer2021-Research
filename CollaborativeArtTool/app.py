# Code from https://www.youtube.com/watch?v=mqhxxeeTbu0&ab_channel=TechWithTim

from flask import Flask, redirect, url_for, render_template

app = Flask(__name__)

@app.route("/")

def home():
    return render_template("index.html")

if __name__ == "__main__":
    app.run()
