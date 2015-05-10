#!/usr/bin/python

import os,sys

def read_db(filename):
    db = {}
    if os.path.exists(filename):
        fp = open(filename, "rb")
        for line in fp:
            [ ip,path,ts,offset ]  = line.rstrip().split("|")
            db[ip,path] = (ts,int(offset))
    return db

def write_db(db, filename):
    f = "%s.tmp" % filename
    wp = open(f, "wb")
    for (ip,path),(ts,offset) in sorted(db.items()):
        wp.write("%s|%s|%s|%d\n" % (ip, path, ts, offset))
    wp.close()
    os.rename(f, filename)

def update_db(db, fp, offset):
    for line in fp:
        [ ip,path,ts ]  = line.rstrip().split("|")
        db[ip,path] = (ts, offset)

def min_offset(db, fp):
    offset = 0
    for line in fp:
        [ ip,path,ts ]  = line.rstrip().split("|")
        if (ip,path) not in db: return 0
        old_ts,old_offset = db[ip,path]
        if ts != old_ts: return 0
        if offset == 0 or old_offset < offset:
            offset = old_offset
    return offset

def main():
    op = sys.argv[1]
    filename = sys.argv[2]
    db = read_db(filename)
    if op == "update":
        offset = int(sys.argv[3])
        update_db(db, sys.stdin, offset)
        write_db(db, filename)
        return 0
    elif op == "min_offset":
        o = min_offset(db, sys.stdin)
        sys.stdout.write("%s\n" % o)
        return 0
    else:
        sys.stderr.write("unknown op %s\n" % op)
        return 1

sys.exit(main())

