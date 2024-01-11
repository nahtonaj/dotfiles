local augroup = vim.api.nvim_create_augroup       -- Create/get autocommand group
local autocmd = vim.api.nvim_create_autocmd       -- Create autocommand
local usercmd = vim.api.nvim_create_user_command   -- Create usercommand

vim.g.firenvim_config = {
    globalSettings = { alt = "all" },
    localSettings = {
        [".*"] = {
            cmdline  = "neovim",
            content  = "text",
            priority = 0,
            selector = "textarea",
            takeover = "never"
        }
    }
}

autocmd({'UIEnter'}, {
    callback = function(event)
        local client = vim.api.nvim_get_chan_info(vim.v.event.chan).client
        if client ~= nil and client.name == "Firenvim" then
            vim.opt.guifont = { 'Hack Nerd Font', ':h14'}
        end
    end
})
