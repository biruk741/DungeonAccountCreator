import ldap
import sys
import os
import csv
import crypt

user_list_file = []
user_entries = []

if not len(sys.argv) == 1:
    print(f"usage: {os.path.basename(__file__)}")
    sys.exit()
with open(sys.argv[0]) as f:
    user_list_file = f.read()
    csv_reader = csv.reader(user_list_file, delimiter=',')
    for entry in csv_reader:
        user_entries.append(entry)

conn = ldap.initialize('ldap://server01.morris.umn.edu:389') 

""" Work in progress """
def generateSalt(len=8):
    longEnough = false;
    finalSalt = ""
    while not longEnough:
        salt = crypt.mksalt(crypt.METHOD_SHA512)
        if len <= len(salt):
            longEnough = true;
            finalSalt = salt[0,len]
        else:
            finalSalt += salt
            longEnough = false;

    
