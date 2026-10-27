# Fedora installation

Tested on Fedora 44 KDE (x86_64).

Download `mavernix-0.1.4-2.fc44.x86_64.rpm` from this folder, then run:

```sh
cd ~/Downloads
sudo dnf install ./mavernix-0.1.4-2.fc44.x86_64.rpm
```

DNF installs the required dependencies. Log out and select Mavernix
on the login screen.

To uninstall:

```sh
sudo dnf remove mavernix
```