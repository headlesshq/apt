# HeadlessHQ apt repository

[apt](https://wiki.debian.org/Apt) repository for HeadlessHQ projects, for Debian, Ubuntu and their derivatives
on amd64 and arm64.

```shell
sudo install -d -m 0755 /etc/apt/keyrings
curl -fsSL https://headlesshq.github.io/apt/headlesshq.gpg | sudo tee /etc/apt/keyrings/headlesshq.gpg > /dev/null
curl -fsSL https://headlesshq.github.io/apt/headlesshq.sources | sudo tee /etc/apt/sources.list.d/headlesshq.sources > /dev/null
sudo apt update
sudo apt install headlessmc
```

### Uninstall

```shell
sudo apt remove headlessmc
sudo rm /etc/apt/sources.list.d/headlesshq.sources /etc/apt/keyrings/headlesshq.gpg
sudo apt update
```
