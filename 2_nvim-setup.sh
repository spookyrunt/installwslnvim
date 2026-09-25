#!/bin/bash
set -euo pipefail

# Neovim + LazyVim setup script

echo "==> Updating apt..."
sudo apt update && sudo apt upgrade -y

echo "==> Installing dependencies..."
sudo apt install -y git curl jq unzip build-essential \
  xclip xsel language-pack-ko \
  ripgrep fd-find fzf sd \
  python3 python3-pip nodejs npm

# fd-find installs as fdfind, LazyVim expects fd
if ! command -v fd &>/dev/null; then
  sudo ln -sf $(which fdfind) /usr/local/bin/fd
fi

RELEASE_JSON="$(curl -fsSL https://api.github.com/repos/neovim/neovim/releases/latest)"
NVIM_LATEST_TAG="$(jq -er '.tag_name' <<<"$RELEASE_JSON")"
CURRENT_VERSION="$(
  nvim --version 2>/dev/null |
    sed -n '1s/^NVIM //p' ||
    true
)"
if [[ "$CURRENT_VERSION" == "$NVIM_LATEST_TAG" ]]; then
  echo "Neovim is already installed and up to date ($CURRENT_VERSION). Skipping."
  exit 0
fi

echo "==> Installing latest stable Neovim..."
NVIM_URL="$(
  jq -er '
    .assets[]
    | select(.name == "nvim-linux-x86_64.tar.gz")
    | .browser_download_url
  ' <<<"$RELEASE_JSON"
)"
if [[ -z "$NVIM_URL" || "$NVIM_URL" == "null" ]]; then
  echo "Error: Failed to fetch the Neovim download URL."
  exit 1
fi

TMP_DIR="$(mktemp -d)"
curl -fL "$NVIM_URL" -o "$TMP_DIR/nvim.tar.gz"
tar -xzf "$TMP_DIR/nvim.tar.gz" -C "$TMP_DIR"
sudo rm -rf /opt/nvim
sudo mv "$TMP_DIR/nvim-linux-x86_64" /opt/nvim
sudo ln -sf /opt/nvim/bin/nvim /usr/local/bin/nvim
rm -rf "$TMP_DIR"
echo "Neovim $(nvim --version | head -n 1) installed"

echo "==> Registering nvim as system default editor..."
sudo update-alternatives --install /usr/bin/editor editor /usr/local/bin/nvim 60
sudo update-alternatives --set editor /usr/local/bin/nvim
if ! grep -q "export EDITOR=/usr/local/bin/nvim" ~/.profile 2>/dev/null; then
  printf '\nexport EDITOR=/usr/local/bin/nvim' >>~/.profile
fi
if ! grep -q "export VISUAL=/usr/local/bin/nvim" ~/.profile 2>/dev/null; then
  printf '\nexport VISUAL=/usr/local/bin/nvim' >>~/.profile
fi
git config --global core.editor "nvim"
sudo git config --global core.editor "nvim"

echo "==> Installing LazyVim..."
# Back up existing config if present
[ -d ~/.config/nvim ] && mv ~/.config/nvim ~/.config/nvim.bak.$(date +%s)
git clone https://github.com/LazyVim/starter ~/.config/nvim
rm -rf ~/.config/nvim/.git

echo "==> Writing LazyVim plugin configs..."
mkdir -p ~/.config/nvim/lua/plugins

cat >~/.config/nvim/lua/plugins/colorscheme.lua <<'EOF'
return {
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "catppuccin-latte",
    },
  },
}
EOF

cat >~/.config/nvim/lua/plugins/korean.lua <<'EOF'
return {
  {
    "kiyoon/Korean-IME.nvim",
    keys = {
      {
        "<f12>",
        function() require("korean_ime").change_mode() end,
        mode = { "i", "n", "x", "s" },
        desc = "한/영",
      },
    },
    config = function()
      require("korean_ime").setup()
      vim.keymap.set("i", "<f9>", function()
        require("korean_ime").convert_hanja()
      end, { noremap = true, silent = true, desc = "한자" })
    end,
  },
}
EOF

cat >~/.config/nvim/lua/plugins/vimbegood.lua <<'EOF'
return {
  {
    "ThePrimeagen/vim-be-good",
    lazy = false,
  },
}
EOF

echo "==> Creating Windows file opener wrapper..."
cat >~/nvim-open.sh <<'EOF'
#!/bin/bash
nvim "$(wslpath -a "$1")"
EOF
chmod +x ~/nvim-open.sh

echo ""
echo "==> Done!"
