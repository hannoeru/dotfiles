# Devcontainer base image: Ubuntu + Nix + this repo's home-manager
# activation. Published to ghcr.io by .github/workflows/devcontainer.yml.

FROM ubuntu:noble

ARG USERNAME=hanlee
ARG USER_UID=1000
ARG USER_GID=1000

ENV LANG=C.UTF-8

# Nix provides the development toolchains through home-manager, so the image
# only carries what Nix itself and the VS Code server need.
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        git \
        less \
        openssh-client \
        procps \
        sudo \
    && rm -rf /var/lib/apt/lists/*

# ubuntu:noble ships a default user that occupies uid/gid 1000.
RUN userdel --remove ubuntu 2>/dev/null || true \
    && groupadd --gid "$USER_GID" "$USERNAME" \
    && useradd --uid "$USER_UID" --gid "$USER_GID" --no-create-home --shell /bin/bash "$USERNAME" \
    && mkdir --parents "/home/$USERNAME" \
    && chown "$USER_UID:$USER_GID" "/home/$USERNAME" \
    && echo "$USERNAME ALL=(root) NOPASSWD:ALL" > "/etc/sudoers.d/$USERNAME" \
    && chmod 0440 "/etc/sudoers.d/$USERNAME"

# Multi-user install without an init system: Nix itself lives in the system
# default profile, which leaves the user profile free for home-manager.
RUN curl --proto '=https' --tlsv1.2 -sSf -L \
        https://install.determinate.systems/nix/tag/v3.22.2/nix-installer.sh \
        -o /tmp/nix-installer.sh \
    && sh /tmp/nix-installer.sh install linux --init none --no-confirm \
    && rm /tmp/nix-installer.sh \
    # Docker's default seccomp profile blocks the user namespaces the Nix
    # build sandbox requires, so builds run unsandboxed instead.
    && printf 'experimental-features = nix-command flakes\nsandbox = false\n' > /etc/nix/nix.conf \
    # The user operates the store directly; no daemon runs during the build
    # or inside the devcontainer. A metadata-only chown in its own layer
    # would copy the store bytes again, so ownership is fixed here.
    && chown -R "$USER_UID:$USER_GID" /nix/var /nix/store

USER "$USERNAME"
# home-manager's wrapper requires $USER; docker build sets neither HOME nor USER.
ENV HOME=/home/$USERNAME
ENV USER=$USERNAME
ENV PATH="/home/$USERNAME/.nix-profile/bin:/nix/var/nix/profiles/default/bin:$PATH"
ENV NIX_SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
WORKDIR /home/$USERNAME

# Apply the dotfiles. Language runtimes are not pre-installed: mise's
# auto-install hook installs each one the first time it is used, which
# keeps the image small. The build context is this repository; the flake
# exposes one home configuration per architecture.
ARG TARGETARCH
COPY --chown="$USER_UID:$USER_GID" . /tmp/dotfiles
RUN if [ "$TARGETARCH" = "arm64" ]; then home_config="ephemeral-aarch64"; else home_config="ephemeral"; fi \
    && nix run /tmp/dotfiles#home-manager -- switch -b backup --flake "/tmp/dotfiles#$home_config" \
    # Build-time paths that no gcroot reaches must go in this same RUN; a
    # later RUN could not shrink this layer. Optimise hardlinks the rest.
    && nix store gc \
    && nix store optimise \
    && rm -rf /tmp/dotfiles

# zsh comes from home-manager; chsh needs the path in /etc/shells.
USER root
RUN zsh="/home/$USERNAME/.nix-profile/bin/zsh" \
    && echo "$zsh" >> /etc/shells \
    && chsh --shell "$zsh" "$USERNAME"

USER "$USERNAME"
CMD [ "sleep", "infinity" ]
