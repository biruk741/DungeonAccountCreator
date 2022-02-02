import ldap
import sys
import os
import csv

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

con = ldap.initialize('ldap://localhost') 
