# -*- coding: utf-8 -*-

import psycopg2
import sys

from config_db import *
from sql import *
import sql

from os import walk
import os

import datetime



def run_sql ():
    connstring_pg = r'dbname=%s user=%s password=%s host=%s' % (DB_NAME, DB_USER, DB_PASS, DB_HOST)
    con = psycopg2.connect(connstring_pg)
    try:
        cur = con.cursor()
        for (dirpath, dirnames, filenames) in walk('sql'):
            for file in sorted(filenames):
                if file.endswith(".py") and not file.startswith("__"):
                    method = os.path.splitext(file)[0]
                    query_sql = getattr(sql, method)
                    print 'start query ' + file
                    a = datetime.datetime.now() 
                    cur.execute(query_sql.q)
                    b = datetime.datetime.now()
                    c = b-a                    
                    print 'executed query ' + file + ' in:' 
                    print c 
        con.commit()
    except psycopg2.DatabaseError, e:
        if con:
            con.rollback()
        print 'Error %s' % e
        sys.exit(1)
    finally:
        if con:
            con.close()

def main():
    run_sql()


if __name__ == "__main__":
    main()
