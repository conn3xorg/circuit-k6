# Local example

Applies circuit-k6 to a throwaway Rocky Linux 10 container with systemd. You need Conn3x and Podman.

```sh
./up.sh
conn3x init
conn3x apply
conn3x plan
```

The second plan says `No changes.` Then check k6 is there:

```sh
ssh -p 2222 -i id_ed25519 -o UserKnownHostsFile=known_hosts root@127.0.0.1 k6 version
```

Want to see it run a test? `check.sh` starts a small HTTP listener in the container, runs a k6 test of five requests against it and checks the summary k6 exports. Then it points the same test at a closed port and checks k6 fails it. It installs `python3` for the listener if the image hasn't got it:

```sh
podman exec -i circuit-k6 sh < check.sh
```

`up.sh` listens on `127.0.0.1:2222`. Set `PORT` to use another port, and pass the same port to Conn3x with `-var port=PORT`. Set `CONTAINER_NAME` to name the container something other than `circuit-k6`, and use that name with `podman exec`. Set `CONTAINERFILE` to test another distro, such as one of the images in Conn3x's `test/images`, which CI uses. On a Mac, rootful Podman is simplest: `export CONTAINER_CONNECTION=podman-machine-default-root`.

`./down.sh` removes the container, its volumes, the key and the state.
