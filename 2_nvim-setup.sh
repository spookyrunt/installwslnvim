#!/bin/bash
# Neovim + LazyVim setup script for WSL Ubuntu
# Run this inside WSL after completing Ubuntu first-run setup

set -e

echo "==> Updating apt..."
sudo apt update && sudo apt upgrade -y

echo "==> Installing dependencies..."
sudo apt install -y git curl unzip ripgrep fd-find python3 python3-pip nodejs npm

# fd-find installs as fdfind, LazyVim expects fd
if ! command -v fd &>/dev/null; then
  sudo ln -sf $(which fdfind) /usr/local/bin/fd
fi

echo "==> Installing latest stable Neovim..."
NVIM_URL=$(curl -s https://api.github.com/repos/neovim/neovim/releases/latest |
  grep "browser_download_url.*nvim-linux-x86_64.tar.gz\"" |
  cut -d '"' -f 4)
curl -LO "$NVIM_URL"
tar xzf nvim-linux-x86_64.tar.gz
sudo rm -rf /opt/nvim
sudo mv nvim-linux-x86_64 /opt/nvim
sudo ln -sf /opt/nvim/bin/nvim /usr/local/bin/nvim
rm nvim-linux-x86_64.tar.gz
echo "Neovim $(nvim --version | head -1) installed"

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
echo "==> Done! Run 'wsl --shutdown' then reopen WSL to apply changes."
