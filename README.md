# Private Passage

Private Passage is a simple and secure way to share sensitive data with anyone.
It is a single web page that encrypts and decrypts user-supplied data using the
modern encryption capabilities of your own browser. The encrypted data is
relayed via a tiny websocket server and is never stored anywhere.

The code aims to be as simple and as readable as possible. The front-end has no
3rd party dependencies, and requires only a few hundred lines of code all
contained in a single HTML file.

For the best security, you can host your own instance of the static index.html
wherever you like. You will also want to copy theme.css or supply your own
custom CSS.

## How it works

When you generate a private link, the browser creates a unique secret key that
is used to encrypt the data. This secret key is set as the hash portion of the
private link's URL, so the key is never sent to any server.

Once encrypted, the browser connects to the websocket relay server and waits for
a recipient to connect. Once a recipient connects, the data is relayed to them
directly and the connection is closed. The recipient can then decrypt the data
using the secret key that was shared via the private link.

## Why?

Too often, sensitive data is shared over insecure channels like Slack, MS Teams,
or email. These messages are not encrypted, and even if they are subsequently
deleted, notification emails may have been sent that included the secret.

Furthermore, while many password managers support sharing passwords, the process
is much more cumbersome and I occasionally need to share sensitive data with
people who do not use the same password manager as me.

## Goals

- [x] Simple
- [x] Secure
- [x] Easily auditable
- [x] Self-hostable
- [x] No 3rd party dependencies
- [x] No tracking
- [x] No data at rest (not even on the server)
