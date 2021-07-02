import json

def main():
    # read json object
    a_file = open("./tokenURI/tokenURI.json", "r")
    json_object = json.load(a_file)
    a_file.close()

    # adding json element
    json_object["2"] = "hey there bob"
    a_file = open("./tokenURI/tokenURI.json", "w")
    json.dump(json_object, a_file)
    a_file.close()

    a_file = open("./tokenURI/tokenURI.json", "r")
    json_object = json.load(a_file)
    a_file.close()
    print(json_object)

    # removing json element
    json_object.pop("0")
    a_file = open("./tokenURI/tokenURI.json", "w")
    json.dump(json_object, a_file)
    a_file.close()

    a_file = open("./tokenURI/tokenURI.json", "r")
    json_object = json.load(a_file)
    a_file.close()
    print(json_object)
