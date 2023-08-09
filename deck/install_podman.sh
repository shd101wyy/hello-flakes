#!/bin/sh
# https://engineering.zeroitlab.com/2022/09/20/develop-on-deck/

# Check `distrobox` is installed
if [[ ! -f "$HOME/.local/bin/distrobox" ]]; then
  echo "* Installing distrobox"
  curl -s https://raw.githubusercontent.com/89luca89/distrobox/main/install | sh -s -- --prefix ~/.local
else
  echo "* distrobox is already installed"
fi

if [[ ! -f "$HOME/.local/podman/bin/podman" ]]; then
  echo "* Installing podman"
  curl -s https://raw.githubusercontent.com/89luca89/distrobox/main/extras/install-podman | sh -s -- --prefix ~/.local
else
  echo "* podman is already installed"
fi

if [[ ! -d "$HOME/.config/systemd/user" ]]; then
  mkdir -p $HOME/.config/systemd/user
fi

# Install podman services
echo "* Installing podman services"
cp ./services/podman.service $HOME/.config/systemd/user/podman.service
cp ./services/podman.socket $HOME/.config/systemd/user/podman.socket

# Make the socket user service automatically start on login:
echo "* Enabling podman.socket"
systemctl --user enable podman.socket

# Start the socket user service:
echo "* Starting podman.socket"
systemctl --user start podman.socket

# Make the podman service automatically start on login:
echo "* Enabling podman.service"
systemctl --user enable podman.service

# Start the podman service:
echo "* Starting podman.service"
systemctl --user start podman.service

# Allow the podman socket to be passed through to Flatpaks:
echo "* Allowing podman.socket to be passed through to Flatpaks"
flatpak override --user --filesystem=/run/user/1000/podman/podman.sock

# Add ability to run X applications from container
xhost +si:localuser:$USER
echo 'xhost +si:localuser:$USER' > $HOME/.xinitrc

echo "* Done. You may need to reboot your device."