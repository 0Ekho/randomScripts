#!/usr/bin/env python3

# MIT License
# Copyright (c) 2019 Ekho <ekho@ekho.email>

# upload and notifications script for capture.sh
# allows for providing more functionallity than possible with curl(1)
# and the unfortunatly feature missing notify-send(1)

# requires pycurl, python3-dbus, and xclip


import argparse
from datetime import datetime
from io import BytesIO
import json
from os import path, environ
import re
from subprocess import Popen, PIPE, DEVNULL
from sys import exit
import dbus
import pycurl


# -----------------------------------------------------------------------------
main_dir = path.join(environ['HOME'], ".sharenix")


def notify(title, body, time, replace):
    bname = 'org.freedesktop.Notifications'
    path = '/org/freedesktop/Notifications'
    interface = 'org.freedesktop.Notifications'

    bus = dbus.SessionBus()
    notif = dbus.Interface(bus.get_object(bname, path), interface)

    # param: appname, int replace, icon, title, body, action, hint, int time
    return notif.Notify('sharenix.py', replace, '', title, body, '', '', time)


def upload(fname, apikey):
    # Edit URL and API param names for your host, comment out second POST param
    # line if host is public upload
    api_url = "https://x88.moe/api/v1/upload"
    # api_url = "http://x88.devel/api/v1/upload"
    api_param = {'file': "file", 'auth': "apikey"}

    # have to use globals because pycurl doesn't support XFERINFODATA() :/
    global prog_notif_fn
    prog_notif_fn = fname
    global prog_notif_id
    prog_notif_id = notify("Uploading: " + fname, "", 2000, 0)

    err_code = 0
    msg = ""
    buffer = BytesIO()

    c = pycurl.Curl()
    c.exception = None
    c.setopt(c.WRITEDATA, buffer)
    c.setopt(c.URL, api_url)
    c.setopt(c.MAX_SEND_SPEED_LARGE, 4_000_000)  # NOTE: 4MB rate limit
    c.setopt(c.HTTPPOST, [
        (api_param['file'], (c.FORM_FILE, fname)),
        (api_param['auth'], (c.FORM_BUFFERPTR, apikey)),
    ])
    c.setopt(c.NOPROGRESS, False)
    c.setopt(c.XFERINFOFUNCTION, prog_notif)
    # c.setopt(c.XFERINFODATA, (prog_notif_id, fname))

    try:
        c.perform()
    except pycurl.error as e:
        if e.args[0] == pycurl.E_COULDNT_CONNECT and c.exception:
            msg = "ERROR:" + c.exception
            notify("Curl Error:", str(c.exception), 4000, prog_notif_id)
            err_code = 2
        else:
            msg = "ERROR:" + e
            notify("Curl Error:", str(e), 4000, prog_notif_id)
            err_code = 3

    response = buffer.getvalue().decode("utf-8")
    msg = re.sub(r"\s\s+", " ", response).replace("\n", " ")

    if err_code:
        return (err_code, msg)

    resp = json.loads(response)
    if 'ok' in resp and 'url' in resp['ok']:
        notify("Upload Complete",
               "Link is: " + resp['ok']['url'] + "\nUrl copied to clipboard",
               4000, prog_notif_id)
        p = Popen(['xclip', '-i', '-selection', 'clipboard', '-f'],
                  stdin=PIPE, stdout=DEVNULL)
        p.communicate(input=resp['ok']['url'].encode('utf-8'))
        p = Popen(['xclip', '-i', '-selection', 'primary', '-f'],
                  stdin=PIPE, stdout=DEVNULL)
        p.communicate(input=resp['ok']['url'].encode('utf-8'))
    elif 'error' in resp:
        notify("Upload Failed", resp['error'], 4000, prog_notif_id)
        err_code = 4
    else:
        notify("Unknown response", str(response), 4000, prog_notif_id)
        err_code = 5

    return (err_code, msg)


def prog_notif(down_total, down, up_total, up):
    # TODO: Add button to cancel upload?
    notify("Uploading: " + prog_notif_fn,
           "{}B of {}B uploaded".format(up, up_total),
           4000, prog_notif_id)


def run_upload(args):
    with open(path.join(main_dir, "apikey")) as a:
        apikey = a.readline().strip()

    ts = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    (errc, msg) = upload(args.file, apikey)
    print(msg)
    with open(path.join(main_dir, "history.csv"), "a") as h:
        h.write("{},{},{}\n".format(ts, path.abspath(args.file), msg))

    exit(errc)


def run_shorten(args):
    print("TODO:")


def run_notify(args):
    notify(args.title, args.body, args.t, 0)


parser = argparse.ArgumentParser(description="File uploader and notifier")
sub_par = parser.add_subparsers(dest='cmd')

up = sub_par.add_parser('upload', help="Upload a file")
up.add_argument('file', help="File to upload")
up.set_defaults(func=run_upload)

lp = sub_par.add_parser('shorten', help="Shorten a link")
lp.add_argument('url', help="URL to shorten")
lp.set_defaults(func=run_shorten)

np = sub_par.add_parser(
    'notify',
    help="Send notification instead of uploading a file,"
    + " this is for use in the capture script."
)
np.add_argument('-t', help="Time in milliseconds to display notification",
                default=0, type=int)
np.add_argument('title', help="Notification Title")
np.add_argument('body', help="Notification body")
np.set_defaults(func=run_notify)

args = parser.parse_args()
args.func(args)
