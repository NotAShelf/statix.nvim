local M = {}

-- Default configuration
M.config = {
    statix_binary = "statix", -- Path to the statix binary
    auto_check = true,        -- Automatically lint on save
    open_quickfix = false,    -- Automatically open the quickfix window
}

function M.run_statix_check()
    local bufnr = vim.api.nvim_get_current_buf()
    local file_path = vim.api.nvim_buf_get_name(bufnr)

    if file_path == "" then return end -- skip unsaved files

    local cmd = { M.config.statix_binary, "check", "-o", "errfmt", file_path }

    vim.fn.jobstart(cmd, {
        stdout_buffered = true,
        stderr_buffered = true,
        on_stdout = function(_, data)
            -- Add errors to the quickfix list
            -- This expects the errorformat to be set correctly
            if data then
                vim.fn.setqflist({}, "r", {
                    title = "Statix Lint",
                    lines = data,
                    efm = "%f>%l:%c:%t:%n:%m",
                })
                if M.config.open_quickfix then
                    vim.api.nvim_command("cwindow")
                end
            end
        end,
        on_stderr = function(_, data)
            if data and #data > 0 then
                vim.notify(table.concat(data, "\n"), vim.log.levels.ERROR)
            end
        end,
    })
end

local function setup_autocmds()
    local group = vim.api.nvim_create_augroup("StatixCheck", { clear = true })
    vim.api.nvim_create_autocmd("FileType", {
        pattern = "nix",
        callback = function()
            vim.opt_local.errorformat = "%f>%l:%c:%t:%n:%m"
        end,
        group = group,
    })

    if M.config.auto_check then
        vim.api.nvim_create_autocmd("BufWritePost", {
            pattern = "*.nix",
            callback = M.run_statix_check,
            group = group,
        })
    end
end

function M.setup(user_config)
    M.config = vim.tbl_extend("force", M.config, user_config or {})
    if not vim.fn.executable(M.config.statix_binary) then
        vim.notify("Statix binary not found or not executable: " .. M.config.statix_binary, vim.log.levels.ERROR)
    end
    setup_autocmds()
end

return M
