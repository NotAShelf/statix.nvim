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
    if file_path == "" or not vim.loop.fs_stat(file_path) then
        return
    end
    local cmd = { M.config.statix_binary, "check", "-o", "errfmt", file_path }
    vim.fn.jobstart(cmd, {
        stdout_buffered = true,
        stderr_buffered = true,
        on_stdout = function(_, data)
            -- Add any error present to the quickfix list. Errors will be
            -- collected from the output of 'statix check -o errfmt' if
            -- errorformat has been set correctly.
            if not data or #data == 0 then
                return
            end

            vim.fn.setqflist({}, "r", {
                title = "Statix Lint",
                lines = data,
                efm = "%f>%l:%c:%t:%n:%m",
            })
            if M.config.open_quickfix then
                vim.api.nvim_command("cwindow")
            end
        end,
        on_stderr = function(_, data)
            if not data or #data == 0 then
                return
            end
            vim.notify(table.concat(data, "\n"), vim.log.levels.ERROR)
        end,
    })
end

local function check_executable()
    M.config = vim.tbl_extend("force", M.config, user_config or {})
    if not vim.fn.executable(M.config.statix_binary) then
        vim.notify("Statix binary not found or not executable: " .. M.config.statix_binary, vim.log.levels.ERROR)
    end
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

function M.setup()
    check_executable()
    setup_autocmds()
end

return M
