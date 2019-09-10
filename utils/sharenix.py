#!/usr/bin/env python3

# MIT License
# Copyright (c) 2019 Ekho <ekho@ekho.email>

# upload and notifications script for capture.sh
# allows for providing more functionallity than possible with curl(1)
# and the unfortunatly feature missing notify-send(1)

# requires pycurl, python3-dbus, and xclip

from io import BytesIO
import json
import re
from subprocess import Popen, PIPE, DEVNULL
import sys
import dbus
import pycurl


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
            print("ERROR:", c.exception)
            notify("Curl Error:", str(c.exception), 4000, prog_notif_id)
            err_code = 2
        else:
            print("ERROR:", e)
            notify("Curl Error:", str(e), 4000, prog_notif_id)
            err_code = 3

    response = buffer.getvalue().decode("utf-8")
    print(re.sub(r"\s\s+", " ", response).replace("\n", " "))

    if err_code:
        sys.exit(err_code)

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

    if err_code:
        sys.exit(err_code)


def prog_notif(down_total, down, up_total, up):
    # TODO: Add button to cancel upload
    notify("Uploading: " + prog_notif_fn,
           "{}B of {}B uploaded".format(up, up_total),
           4000, prog_notif_id)


if sys.argv[1] == "upload":
    upload(sys.argv[2], sys.argv[3])
elif sys.argv[1] == "notify":
    notify(sys.argv[2], sys.argv[3], int(sys.argv[4]), 0)
else:
    print("Unknown command:", sys.argv[1])
